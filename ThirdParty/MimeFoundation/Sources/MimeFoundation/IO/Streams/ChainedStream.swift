//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//
// ChainedStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A chained stream that combines multiple streams into one continuous stream.
///
/// ``ChainedStream`` chains multiple streams together such that reading or writing
/// beyond the end of one stream spills over into the next stream in the chain.
/// This makes it appear as if the chain of streams is all one continuous stream.
///
/// ## Overview
///
/// Chained streams are useful for:
/// - Combining multiple content parts into a single stream
/// - Building composite MIME messages from separate parts
/// - Reading from multiple data sources as if they were one
///
/// ## Capabilities
///
/// The ``ChainedStream`` only supports a capability (read, write, seek) if ALL of its
/// child streams support that capability. An empty ``ChainedStream`` reports that it
/// cannot read, write, or seek.
///
/// ## Example Usage
///
/// ```swift
/// let chain = ChainedStream()
/// try chain.add(headerStream)
/// try chain.add(boundaryStream)
/// try chain.add(contentStream, leaveOpen: true)
///
/// // Read from the combined stream
/// var buffer = [UInt8](repeating: 0, count: 1024)
/// while true {
///     let bytesRead = try chain.read(&buffer, offset: 0, count: buffer.count)
///     if bytesRead == 0 { break }
///     // Process buffer...
/// }
/// ```
///
/// ## Thread Safety
///
/// ``ChainedStream`` is not thread-safe. External synchronization is required
/// when accessing a chained stream from multiple threads.
public final class ChainedStream: ResizableStream {
    private var streams: [MimeStream] = []
    private var leaveOpen: [Bool] = []
    private var currentPosition: Int = 0
    private var currentIndex: Int = 0
    private var eos = false
    private var closed = false

    /// Initializes a new instance of the ``ChainedStream`` class.
    ///
    /// Creates a new empty ``ChainedStream``. Use ``add(_:leaveOpen:)`` to add
    /// streams to the chain.
    public init() {}

    /// Adds a stream to the end of the chain.
    ///
    /// - Parameters:
    ///   - stream: The stream to add to the chain.
    ///   - leaveOpen: `true` if the stream should remain open after the
    ///     ``ChainedStream`` is closed; otherwise, `false`. Defaults to `false`.
    ///
    /// - Throws: ``StreamError/invalidArgument`` if `stream` is `nil`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let chain = ChainedStream()
    /// try chain.add(firstStream)  // Will be closed when chain is closed
    /// try chain.add(secondStream, leaveOpen: true)  // Will remain open
    /// ```
    public func add(_ stream: MimeStream?, leaveOpen: Bool = false) throws {
        guard let stream else {
            throw StreamError.invalidArgument
        }
        streams.append(stream)
        self.leaveOpen.append(leaveOpen)
        eos = false
    }

    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// The ``ChainedStream`` only supports reading if ALL of its streams
    /// support reading. Returns `false` if the chain is empty.
    public var canRead: Bool {
        !streams.isEmpty && streams.allSatisfy { $0.canRead }
    }

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// The ``ChainedStream`` only supports writing if ALL of its streams
    /// support writing. Returns `false` if the chain is empty.
    public var canWrite: Bool {
        !streams.isEmpty && streams.allSatisfy { $0.canWrite }
    }

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// The ``ChainedStream`` only supports seeking if ALL of its streams
    /// support seeking. Returns `false` if the chain is empty.
    public var canSeek: Bool {
        !streams.isEmpty && streams.allSatisfy { $0.canSeek }
    }

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// The ``ChainedStream`` does not support timeouts.
    public var canTimeout: Bool { false }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// Since ``ChainedStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var readTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// Since ``ChainedStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var writeTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets the current position within the stream.
    ///
    /// It is always possible to get the position of a ``ChainedStream``,
    /// but setting the position is only possible if all of its streams are seekable.
    public var position: Int {
        get { currentPosition }
        set {
            _ = try? seek(newValue, origin: .begin)
        }
    }

    /// Gets the length of the stream in bytes.
    ///
    /// The length of a ``ChainedStream`` is the combined lengths of all
    /// of its chained streams.
    public var length: Int {
        streams.reduce(0) { $0 + $1.length }
    }

    /// Reads a sequence of bytes from the stream and advances the position
    /// within the stream by the number of bytes read.
    ///
    /// Reads up to the requested number of bytes. If the current child stream
    /// does not have enough remaining data to complete the read, the read will
    /// progress into the next stream in the chain.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes. When this method returns, the buffer contains
    ///     the specified byte array with the values between `offset` and
    ///     `(offset + count - 1)` replaced by the bytes read from the current source.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin storing
    ///     the data read from the current stream.
    ///   - count: The maximum number of bytes to be read from the current stream.
    ///
    /// - Returns: The total number of bytes read into the buffer. This can be less than
    ///   the number of bytes requested if that many bytes are not currently available,
    ///   or zero if the end of the stream has been reached.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   ``StreamError/notSupported`` if the stream does not support reading,
    ///   or ``StreamError/invalidArgument`` if the arguments are invalid.
    public func read(_ buffer: inout [UInt8], offset: Int, count: Int) throws -> Int {
        try ensureOpen()
        guard canRead else {
            throw StreamError.notSupported
        }
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
            throw StreamError.invalidArgument
        }
        if count == 0 || eos {
            return 0
        }
        var totalRead = 0

        while currentIndex < streams.count {
            while totalRead < count {
                let nread = try streams[currentIndex].read(&buffer, offset: offset + totalRead, count: count - totalRead)
                if nread <= 0 {
                    break
                }
                totalRead += nread
            }

            if totalRead == count {
                break
            }

            currentIndex += 1
        }

        if totalRead > 0 {
            currentPosition += totalRead
        } else {
            eos = true
        }

        return totalRead
    }

    /// Writes a sequence of bytes to the stream and advances the current
    /// position within this stream by the number of bytes written.
    ///
    /// Writes the requested number of bytes. If the current child stream does
    /// not have enough remaining space to fit the complete buffer, the data will
    /// spill over into the next stream in the chain.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes containing the data to write.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin
    ///     copying bytes to the current stream.
    ///   - count: The number of bytes to be written to the current stream.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   ``StreamError/notSupported`` if the stream does not support writing,
    ///   or ``StreamError/invalidArgument`` if the arguments are invalid.
    public func write(_ buffer: [UInt8], offset: Int, count: Int) throws {
        try ensureOpen()
        guard canWrite else {
            throw StreamError.notSupported
        }
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
            throw StreamError.invalidArgument
        }
        if count == 0 {
            return
        }

        if currentIndex >= streams.count {
            currentIndex = max(streams.count - 1, 0)
        }

        var totalWritten = 0

        while currentIndex < streams.count && totalWritten < count {
            var toWrite = count - totalWritten
            if currentIndex + 1 < streams.count {
                let remaining = streams[currentIndex].length - streams[currentIndex].position
                if remaining < toWrite {
                    toWrite = remaining
                }
            }

            try streams[currentIndex].write(buffer, offset: offset + totalWritten, count: toWrite)
            currentPosition += toWrite
            totalWritten += toWrite

            if totalWritten < count {
                try streams[currentIndex].flush()
                currentIndex += 1
            }
        }
    }

    /// Sets the position within the current stream.
    ///
    /// Seeks to the specified position if all child streams support seeking.
    ///
    /// - Parameters:
    ///   - offset: A byte offset relative to the `origin` parameter.
    ///   - origin: A value of type ``SeekOrigin`` indicating the reference point
    ///     used to obtain the new position.
    ///
    /// - Returns: The new position within the current stream.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   ``StreamError/notSupported`` if the stream does not support seeking,
    ///   or ``StreamError/outOfRange`` if the resulting position is invalid.
    public func seek(_ offset: Int, origin: SeekOrigin) throws -> Int {
        try ensureOpen()
        guard canSeek else {
            throw StreamError.notSupported
        }
        let real: Int
        switch origin {
        case .begin:
            real = offset
        case .current:
            real = currentPosition + offset
        case .end:
            real = length + offset
        }

        if real < 0 || real > length {
            throw StreamError.outOfRange
        }

        if real == currentPosition {
            return currentPosition
        }

        if real > currentPosition {
            while currentIndex < streams.count && currentPosition < real {
                let left = streams[currentIndex].length - streams[currentIndex].position
                let step = min(left, real - currentPosition)
                _ = try streams[currentIndex].seek(step, origin: .current)
                currentPosition += step
                if currentPosition < real {
                    currentIndex += 1
                }
            }
            eos = currentIndex >= streams.count
        } else {
            let maxIndex = min(streams.count - 1, currentIndex)
            var cur = 0
            currentPosition = 0

            while cur <= maxIndex {
                let len = streams[cur].length
                if real < currentPosition + len {
                    _ = try streams[cur].seek(real - currentPosition, origin: .begin)
                    currentPosition = real
                    break
                }
                currentPosition += len
                cur += 1
            }

            currentIndex = cur
            var reset = cur + 1
            while reset <= maxIndex {
                _ = try streams[reset].seek(0, origin: .begin)
                reset += 1
            }
            eos = false
        }

        return currentPosition
    }

    /// Clears all buffers for this stream and causes any buffered data to be written
    /// to the underlying device.
    ///
    /// Flushes all child streams in the chain.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    public func flush() throws {
        try ensureOpen()
        for stream in streams {
            try stream.flush()
        }
    }

    /// Closes the stream and releases any resources associated with it.
    ///
    /// Child streams that were added with `leaveOpen: false` will be closed.
    /// Child streams added with `leaveOpen: true` will remain open.
    public func close() {
        closed = true
        for (index, stream) in streams.enumerated() where !leaveOpen[index] {
            stream.close()
        }
    }

    /// Sets the length of the stream.
    ///
    /// Setting the length of a ``ChainedStream`` is not supported.
    ///
    /// - Parameter length: The desired length of the stream in bytes.
    ///
    /// - Throws: Always throws ``StreamError/notSupported``.
    public func setLength(_ length: Int) throws {
        try ensureOpen()
        throw StreamError.notSupported
    }

    private func streamIndex(for position: Int) -> (Int, Int) {
        var remaining = position
        for (index, stream) in streams.enumerated() {
            let len = stream.length
            if remaining < len {
                return (index, remaining)
            }
            remaining -= len
        }
        return (streams.count, 0)
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
