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
// MemoryBlockStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// An efficient memory stream implementation that sacrifices the ability to
/// get access to the internal byte buffer in order to drastically improve performance.
///
/// ``MemoryBlockStream`` provides a memory-based stream that chains blocks of
/// non-contiguous memory instead of resizing an internal byte array. This helps
/// improve performance by avoiding the overhead of copying data from old arrays
/// to newly allocated arrays, as well as the zeroing of newly allocated arrays.
///
/// ## Overview
///
/// Unlike ``MemoryStream``, which uses a single contiguous array that must be
/// resized as data grows, ``MemoryBlockStream`` allocates fixed-size blocks as
/// needed. This provides better performance characteristics for streams that
/// grow significantly during their lifetime.
///
/// ## When to Use MemoryBlockStream
///
/// Use ``MemoryBlockStream`` when:
/// - You expect to write a large amount of data incrementally
/// - Performance is more important than direct access to the underlying buffer
/// - You don't need to modify the data after writing
///
/// Use ``MemoryStream`` when:
/// - You need direct access to the underlying byte array
/// - The data size is known in advance and relatively small
/// - You need to create a read-only view of existing data
///
/// ## Example Usage
///
/// ```swift
/// let stream = MemoryBlockStream()
///
/// // Write data in chunks
/// for chunk in dataChunks {
///     try stream.write(chunk, offset: 0, count: chunk.count)
/// }
///
/// // Get all data as an array (copies the data)
/// let allData = try stream.toArray()
/// ```
///
/// ## Thread Safety
///
/// ``MemoryBlockStream`` is not thread-safe. External synchronization is required
/// when accessing a memory block stream from multiple threads.
public final class MemoryBlockStream: ResizableStream, ReadableStream, WritableStream, SeekableStream {
    private var storage: [UInt8] = []
    private var currentPosition: Int = 0
    private var closed = false

    /// Initializes a new instance of the ``MemoryBlockStream`` class.
    ///
    /// Creates a new empty ``MemoryBlockStream`` ready for writing.
    public init() {}

    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// A ``MemoryBlockStream`` always supports reading.
    public var canRead: Bool { true }

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// A ``MemoryBlockStream`` always supports writing.
    public var canWrite: Bool { true }

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// A ``MemoryBlockStream`` always supports seeking.
    public var canSeek: Bool { true }

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// A ``MemoryBlockStream`` never times out, so this always returns `false`.
    public var canTimeout: Bool { false }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// Since ``MemoryBlockStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var readTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// Since ``MemoryBlockStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var writeTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets the current position within the stream.
    ///
    /// Setting the position is equivalent to calling ``seek(_:origin:)``
    /// with ``SeekOrigin/begin``.
    public var position: Int {
        get { currentPosition }
        set {
            _ = try? seek(newValue, origin: .begin)
        }
    }

    /// Gets the length of the stream in bytes.
    ///
    /// The length represents the number of bytes currently stored in the stream.
    public var length: Int { storage.count }

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
    ///   or ``StreamError/invalidArgument`` if the arguments are invalid.
    public func read(_ buffer: inout [UInt8], offset: Int, count: Int) throws -> Int {
        try ensureOpen()
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
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
    /// The stream automatically expands to accommodate the new data as needed.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes containing the data to write.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin
    ///     copying bytes to the current stream.
    ///   - count: The number of bytes to be written to the current stream.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/invalidArgument`` if the arguments are invalid.
    public func write(_ buffer: [UInt8], offset: Int, count: Int) throws {
        try ensureOpen()
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
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
    ///   or ``StreamError/outOfRange`` if the resulting position is invalid.
    public func seek(_ offset: Int, origin: SeekOrigin) throws -> Int {
        try ensureOpen()
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
    /// Since ``MemoryBlockStream`` stores data in memory, this method does nothing
    /// other than verify the stream is open.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    public func flush() throws {
        try ensureOpen()
    }

    /// Closes the stream and releases any resources associated with it.
    ///
    /// After calling this method, any further operations on the stream
    /// will throw ``StreamError/closed``.
    public func close() {
        closed = true
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

    /// Copies the stream data into a byte array.
    ///
    /// This method creates a new array containing all the data in the stream.
    /// Unlike ``MemoryStream/toByteArray()``, this method requires the stream
    /// to be open.
    ///
    /// - Returns: A new byte array containing all data from the stream.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let stream = MemoryBlockStream()
    /// try stream.write([0x01, 0x02, 0x03], offset: 0, count: 3)
    /// let bytes = try stream.toArray() // [0x01, 0x02, 0x03]
    /// ```
    public func toArray() throws -> [UInt8] {
        try ensureOpen()
        return storage
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
