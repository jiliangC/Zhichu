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
// BoundStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A bounded stream, confined to reading and writing data to a limited subset
/// of the overall source stream.
///
/// ``BoundStream`` wraps an arbitrary stream, limiting I/O operations to a subset
/// of the source stream defined by start and end boundaries. If the ``endBoundary``
/// is `-1`, then the end of the stream is unbound (extends to the end of the base stream).
///
/// ## Overview
///
/// When a ``MimeParser`` is set to parse a persistent stream, it will construct
/// ``MimeContent`` instances using bounded streams instead of loading the content
/// into memory. This allows efficient access to MIME content without duplicating
/// the underlying data.
///
/// ## Boundaries
///
/// - ``startBoundary``: The byte offset in the base stream that marks the beginning
///   of this substream.
/// - ``endBoundary``: The byte offset in the base stream that marks the end of this
///   substream. A value of `-1` indicates the stream extends to the end of the base stream.
///
/// ## Example Usage
///
/// ```swift
/// // Create a bounded view of bytes 100-200 from a base stream
/// let baseStream = MemoryStream(largeData)
/// let bounded = try BoundStream(baseStream, startBoundary: 100, endBoundary: 200, leaveOpen: true)
///
/// // Read from the bounded region
/// var buffer = [UInt8](repeating: 0, count: 50)
/// let bytesRead = try bounded.read(&buffer, offset: 0, count: 50)
/// ```
///
/// ## Thread Safety
///
/// ``BoundStream`` is not thread-safe. External synchronization is required
/// when accessing a bounded stream from multiple threads.
public final class BoundStream: ResizableStream {
    /// Gets the underlying stream.
    ///
    /// All I/O is performed on the base stream. The base stream's position is
    /// automatically adjusted before each read or write operation.
    public let baseStream: MimeStream

    /// Gets the start boundary offset of the underlying stream.
    ///
    /// The start boundary is the byte offset into the ``baseStream``
    /// that marks the beginning of this substream.
    public let startBoundary: Int

    /// Gets the end boundary offset of the underlying stream.
    ///
    /// The end boundary is the byte offset into the ``baseStream``
    /// that marks the end of this substream. If the value is less than 0,
    /// then the end of the stream is treated as unbound.
    public private(set) var endBoundary: Int

    private let leaveOpen: Bool

    private var currentPosition: Int = 0
    private var closed = false
    private var eos = false

    /// Initializes a new instance of the ``BoundStream`` class.
    ///
    /// If the `endBoundary` is less than 0, then the end of the stream is unbounded.
    ///
    /// - Parameters:
    ///   - baseStream: The underlying stream.
    ///   - startBoundary: The offset in the base stream that will mark the start of this substream.
    ///   - endBoundary: The offset in the base stream that will mark the end of this substream.
    ///     Use `-1` for an unbounded end.
    ///   - leaveOpen: `true` to leave the base stream open after the ``BoundStream`` is closed;
    ///     otherwise, `false`.
    ///
    /// - Throws: ``StreamError/invalidArgument`` if `baseStream` is `nil`,
    ///   or ``StreamError/outOfRange`` if `startBoundary` is less than zero,
    ///   or if `endBoundary` is greater than or equal to zero and is less than `startBoundary`.
    public init(_ baseStream: MimeStream?, startBoundary: Int, endBoundary: Int, leaveOpen: Bool) throws {
        guard let baseStream else {
            throw StreamError.invalidArgument
        }
        if startBoundary < 0 {
            throw StreamError.outOfRange
        }
        if endBoundary >= 0 && endBoundary < startBoundary {
            throw StreamError.outOfRange
        }

        self.baseStream = baseStream
        self.startBoundary = startBoundary
        self.endBoundary = endBoundary < 0 ? -1 : endBoundary
        self.leaveOpen = leaveOpen
    }

    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// The ``BoundStream`` will only support reading if the underlying
    /// ``baseStream`` supports it.
    public var canRead: Bool { baseStream.canRead }

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// The ``BoundStream`` will only support writing if the underlying
    /// ``baseStream`` supports it.
    public var canWrite: Bool { baseStream.canWrite }

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// The ``BoundStream`` will only support seeking if the underlying
    /// ``baseStream`` supports it.
    public var canSeek: Bool { baseStream.canSeek }

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// The ``BoundStream`` will only support timing out if the underlying
    /// ``baseStream`` supports it.
    public var canTimeout: Bool { baseStream.canTimeout }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// Gets or sets the ``baseStream``'s read timeout.
    public var readTimeout: Int {
        get { baseStream.readTimeout }
        set { baseStream.readTimeout = newValue }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// Gets or sets the ``baseStream``'s write timeout.
    public var writeTimeout: Int {
        get { baseStream.writeTimeout }
        set { baseStream.writeTimeout = newValue }
    }

    /// Gets or sets the current position within the stream.
    ///
    /// The position is relative to the ``startBoundary``. Setting the position
    /// is equivalent to calling ``seek(_:origin:)`` with ``SeekOrigin/begin``.
    public var position: Int {
        get { currentPosition }
        set {
            let newPosition = max(0, newValue)
            _ = try? seek(newPosition, origin: .begin)
        }
    }

    /// Gets the length of the stream in bytes.
    ///
    /// If the ``endBoundary`` property is greater than or equal to 0, then the length
    /// will be calculated by subtracting the ``startBoundary`` from the ``endBoundary``.
    /// If the end of the stream is unbound, then the ``startBoundary`` will be subtracted
    /// from the length of the ``baseStream``.
    public var length: Int {
        if endBoundary >= 0 {
            return max(0, endBoundary - startBoundary)
        }
        return max(0, baseStream.length - startBoundary)
    }

    /// Reads a sequence of bytes from the stream and advances the position
    /// within the stream by the number of bytes read.
    ///
    /// Reads data from the ``baseStream``, not allowing it to read beyond
    /// the ``endBoundary``. The base stream is automatically seeked to the
    /// correct position before reading.
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
        if count == 0 {
            return 0
        }
        if endBoundary >= 0 {
            if currentPosition >= length || eos {
                return 0
            }
        }

        if canSeek {
            _ = try baseStream.seek(startBoundary + currentPosition, origin: .begin)
        }

        var available = count
        if endBoundary >= 0 {
            let remaining = length - currentPosition
            if remaining <= 0 {
                eos = true
                return 0
            }
            available = min(available, remaining)
        }

        let nread = try baseStream.read(&buffer, offset: offset, count: available)
        currentPosition += nread
        if nread == 0 {
            eos = true
        }
        return nread
    }

    /// Writes a sequence of bytes to the stream and advances the current
    /// position within this stream by the number of bytes written.
    ///
    /// Writes data to the ``baseStream``, not allowing it to write beyond
    /// the ``endBoundary``. The base stream is automatically seeked to the
    /// correct position before writing.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes containing the data to write.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin
    ///     copying bytes to the current stream.
    ///   - count: The number of bytes to be written to the current stream.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   ``StreamError/notSupported`` if the stream does not support writing,
    ///   ``StreamError/invalidArgument`` if the arguments are invalid,
    ///   or ``StreamError/outOfRange`` if writing would exceed the ``endBoundary``.
    public func write(_ buffer: [UInt8], offset: Int, count: Int) throws {
        try ensureOpen()
        guard canWrite else {
            throw StreamError.notSupported
        }
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
            throw StreamError.invalidArgument
        }

        if endBoundary >= 0 && currentPosition + count > length {
            throw StreamError.outOfRange
        }

        if canSeek {
            _ = try baseStream.seek(startBoundary + currentPosition, origin: .begin)
        }

        try baseStream.write(buffer, offset: offset, count: count)
        currentPosition += count
        eos = false
    }

    /// Sets the position within the current stream.
    ///
    /// Seeks within the confines of the ``startBoundary`` and the ``endBoundary``.
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
        let base: Int
        switch origin {
        case .begin:
            base = 0
        case .current:
            base = currentPosition
        case .end:
            base = length
        }
        let newPosition = base + offset
        guard newPosition >= 0 else {
            throw StreamError.outOfRange
        }
        if endBoundary >= 0, newPosition > length {
            throw StreamError.outOfRange
        }
        currentPosition = newPosition
        eos = false
        if canSeek {
            _ = try baseStream.seek(startBoundary + currentPosition, origin: .begin)
        }
        return currentPosition
    }

    /// Clears all buffers for this stream and causes any buffered data to be written
    /// to the underlying device.
    ///
    /// Flushes the ``baseStream``.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    public func flush() throws {
        try ensureOpen()
        try baseStream.flush()
    }

    /// Closes the stream and releases any resources associated with it.
    ///
    /// If the stream was created with `leaveOpen` set to `false`, the
    /// ``baseStream`` is also closed.
    public func close() {
        closed = true
        if !leaveOpen {
            baseStream.close()
        }
    }

    /// Sets the length of the stream.
    ///
    /// Updates the ``endBoundary`` to be ``startBoundary`` plus the specified
    /// new length. If the ``baseStream`` needs to be grown to allow this, then
    /// the length of the ``baseStream`` will also be updated.
    ///
    /// - Parameter length: The desired length of the stream in bytes.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   ``StreamError/outOfRange`` if `length` is negative,
    ///   or ``StreamError/notSupported`` if the base stream cannot be resized.
    public func setLength(_ length: Int) throws {
        try ensureOpen()
        guard length >= 0 else {
            throw StreamError.outOfRange
        }
        if endBoundary == -1 || startBoundary + length > endBoundary {
            if let resizable = baseStream as? ResizableStream {
                if startBoundary + length > baseStream.length {
                    try resizable.setLength(startBoundary + length)
                }
                endBoundary = startBoundary + length
            } else {
                throw StreamError.notSupported
            }
        } else {
            endBoundary = startBoundary + length
        }
        if currentPosition > self.length {
            currentPosition = self.length
        }
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
