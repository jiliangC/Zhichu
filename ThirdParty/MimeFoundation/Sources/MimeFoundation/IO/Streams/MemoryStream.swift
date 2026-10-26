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
// MemoryStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A stream implementation that stores data in memory.
///
/// ``MemoryStream`` provides a stream backed by an in-memory byte array,
/// supporting reading, writing, and seeking operations. It is useful when
/// you need to work with data in memory as a stream.
///
/// ## Overview
///
/// Memory streams are commonly used for:
/// - Temporary storage of MIME content during processing
/// - Building up data before writing to a file or network
/// - Converting between byte arrays and stream-based APIs
///
/// ## Example Usage
///
/// ```swift
/// // Create an empty writable memory stream
/// let stream = MemoryStream()
///
/// // Write some data
/// let data: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"
/// try stream.write(data, offset: 0, count: data.count)
///
/// // Seek back to the beginning and read
/// _ = try stream.seek(0, origin: .begin)
/// var buffer = [UInt8](repeating: 0, count: 5)
/// let bytesRead = try stream.read(&buffer, offset: 0, count: 5)
///
/// // Get the entire contents as an array
/// let contents = stream.toByteArray()
/// ```
///
/// ## Thread Safety
///
/// ``MemoryStream`` is not thread-safe. External synchronization is required
/// when accessing a memory stream from multiple threads.
public final class MemoryStream: ResizableStream, ReadableStream, SeekableStream {
    private var storage: [UInt8]
    private var closed = false

    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// A ``MemoryStream`` always supports reading.
    public let canRead: Bool

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// The value depends on whether the stream was created with the `writable`
    /// parameter set to `true` (the default).
    public let canWrite: Bool

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// A ``MemoryStream`` always supports seeking.
    public let canSeek: Bool

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// A ``MemoryStream`` never times out, so this always returns `false`.
    public let canTimeout: Bool = false

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// Since ``MemoryStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var readTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// Since ``MemoryStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var writeTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets the current position within the stream.
    ///
    /// The position is clamped to the range `[0, length]` when set.
    public var position: Int {
        get { currentPosition }
        set {
            currentPosition = max(0, min(newValue, storage.count))
        }
    }

    /// Gets the length of the stream in bytes.
    ///
    /// The length represents the number of bytes currently stored in the stream.
    public var length: Int { storage.count }

    private var currentPosition: Int

    /// Initializes a new instance of the ``MemoryStream`` class.
    ///
    /// - Parameters:
    ///   - data: The initial data to populate the stream with. Defaults to an empty array.
    ///   - writable: A value indicating whether the stream supports writing. Defaults to `true`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create an empty writable stream
    /// let emptyStream = MemoryStream()
    ///
    /// // Create a stream initialized with data
    /// let dataStream = MemoryStream([0x01, 0x02, 0x03])
    ///
    /// // Create a read-only stream
    /// let readOnlyStream = MemoryStream([0x01, 0x02, 0x03], writable: false)
    /// ```
    public init(_ data: [UInt8] = [], writable: Bool = true) {
        self.storage = data
        self.canRead = true
        self.canWrite = writable
        self.canSeek = true
        self.currentPosition = 0
    }

    /// Reads a sequence of bytes from the current stream and advances the position
    /// within the stream by the number of bytes read.
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
            print("MemoryStream.write invalidArgument offset=\(offset) count=\(count) buffer.count=\(buffer.count)")
            let symbols = Thread.callStackSymbols.prefix(12).joined(separator: "\n")
            print("MemoryStream.write call stack:\n\(symbols)")
            throw StreamError.invalidArgument
        }
        if currentPosition >= storage.count {
            return 0
        }
        let available = storage.count - currentPosition
        let toRead = min(count, available)
        if toRead > 0 {
            buffer.replaceSubrange(offset..<(offset + toRead), with: storage[currentPosition..<(currentPosition + toRead)])
            currentPosition += toRead
        }
        return toRead
    }

    /// Writes a sequence of bytes to the current stream and advances the current
    /// position within this stream by the number of bytes written.
    ///
    /// If the current position is at the end of the stream, the stream is automatically
    /// expanded to accommodate the new data.
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
            print("MemoryStream.write invalidArgument offset=\(offset) count=\(count) buffer.count=\(buffer.count)")
            throw StreamError.invalidArgument
        }
        let requiredLength = currentPosition + count
        if requiredLength > storage.count {
            storage.append(contentsOf: repeatElement(0, count: requiredLength - storage.count))
        }
        storage.replaceSubrange(currentPosition..<(currentPosition + count), with: buffer[offset..<(offset + count)])
        currentPosition += count
    }

    /// Sets the position within the current stream.
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
            base = storage.count
        }
        let newPosition = base + offset
        guard newPosition >= 0, newPosition <= storage.count else {
            throw StreamError.outOfRange
        }
        currentPosition = newPosition
        return currentPosition
    }

    /// Clears all buffers for this stream.
    ///
    /// Since ``MemoryStream`` stores data in memory, this method does nothing
    /// other than verify the stream is open.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    public func flush() throws {
        try ensureOpen()
    }

    /// Sets the length of the current stream.
    ///
    /// If the specified value is less than the current length, the stream is truncated.
    /// If the specified value is larger than the current length, the stream is expanded
    /// and the new bytes are initialized to zero.
    ///
    /// If the current position is greater than the new length, the position is moved
    /// to the end of the stream.
    ///
    /// - Parameter length: The desired length of the stream in bytes.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/outOfRange`` if `length` is negative.
    public func setLength(_ length: Int) throws {
        try ensureOpen()
        guard length >= 0 else {
            throw StreamError.outOfRange
        }
        if length < storage.count {
            storage.removeLast(storage.count - length)
        } else if length > storage.count {
            storage.append(contentsOf: repeatElement(0, count: length - storage.count))
        }
        if currentPosition > length {
            currentPosition = length
        }
    }

    /// Closes the stream and releases any resources associated with it.
    ///
    /// After calling this method, any further operations on the stream
    /// will throw ``StreamError/closed``.
    public func close() {
        closed = true
    }

    /// Returns the entire contents of the stream as a byte array.
    ///
    /// This method returns a copy of the underlying storage, allowing you to
    /// access the stream data without affecting the stream position.
    ///
    /// - Returns: An array containing all bytes written to the stream.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let stream = MemoryStream()
    /// try stream.write([0x01, 0x02, 0x03], offset: 0, count: 3)
    /// let bytes = stream.toByteArray() // [0x01, 0x02, 0x03]
    /// ```
    public func toByteArray() -> [UInt8] {
        storage
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
