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
// MeasuringStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A stream useful for measuring the amount of data written.
///
/// ``MeasuringStream`` keeps track of the number of bytes that have been written
/// to it without actually storing the data. This is useful when you need to know
/// how large a ``MimeMessage`` or other content would be without actually writing
/// it to disk or into a memory buffer.
///
/// ## Overview
///
/// A measuring stream is write-only and does not store any data. It simply counts
/// the number of bytes written to determine what the final size would be. This is
/// particularly useful for:
///
/// - Calculating the Content-Length header before sending
/// - Estimating message sizes for quota checking
/// - Determining buffer sizes needed for serialization
///
/// ## Example Usage
///
/// ```swift
/// let measuring = MeasuringStream()
///
/// // Write content to measure its size
/// try message.writeTo(measuring, options: formatOptions)
///
/// // Get the size without having stored the data
/// let messageSize = measuring.length
/// ```
///
/// ## Capabilities
///
/// - **Reading**: Not supported (``canRead`` returns `false`)
/// - **Writing**: Always supported (``canWrite`` returns `true`)
/// - **Seeking**: Supported (``canSeek`` returns `true`)
///
/// ## Thread Safety
///
/// ``MeasuringStream`` is not thread-safe. External synchronization is required
/// when accessing a measuring stream from multiple threads.
public final class MeasuringStream: ResizableStream, WritableStream, SeekableStream {
    private var currentPosition: Int = 0
    private var currentLength: Int = 0
    private var closed = false

    /// Initializes a new instance of the ``MeasuringStream`` class.
    ///
    /// Creates a new ``MeasuringStream`` with a length and position of 0.
    public init() {}

    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// A ``MeasuringStream`` is not readable. This always returns `false`.
    public var canRead: Bool { false }

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// A ``MeasuringStream`` is always writable. This always returns `true`.
    public var canWrite: Bool { true }

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// A ``MeasuringStream`` is always seekable. This always returns `true`.
    public var canSeek: Bool { true }

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// Writing to a ``MeasuringStream`` cannot time out. This always returns `false`.
    public var canTimeout: Bool { false }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// Since ``MeasuringStream`` does not support timeouts or reading, this property
    /// always returns 0 and setting it has no effect.
    public var readTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// Since ``MeasuringStream`` does not support timeouts, this property
    /// always returns 0 and setting it has no effect.
    public var writeTimeout: Int {
        get { 0 }
        set { }
    }

    /// Gets or sets the current position within the stream.
    ///
    /// Since it is possible to seek within a ``MeasuringStream``, the position
    /// may not always be identical to the length of the stream, but typically it will be.
    public var position: Int {
        get { currentPosition }
        set {
            _ = try? seek(newValue, origin: .begin)
        }
    }

    /// Gets the length of the stream in bytes.
    ///
    /// The length of a ``MeasuringStream`` indicates the number of bytes
    /// that have been written to it (i.e., the high-water mark of the position).
    public var length: Int { currentLength }

    /// Reads a sequence of bytes from the stream.
    ///
    /// Reading from a ``MeasuringStream`` is not supported.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read data into (unused).
    ///   - offset: The offset into the buffer (unused).
    ///   - count: The number of bytes to read (unused).
    ///
    /// - Throws: Always throws ``StreamError/notSupported``.
    public func read(_ buffer: inout [UInt8], offset: Int, count: Int) throws -> Int {
        try ensureOpen()
        throw StreamError.notSupported
    }

    /// Writes a sequence of bytes to the stream and advances the current
    /// position within this stream by the number of bytes written.
    ///
    /// Increments the ``position`` property by the number of bytes written.
    /// If the updated position is greater than the current length of the stream,
    /// then the ``length`` property will be updated to be identical to the position.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes. The actual content is not stored.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin
    ///     counting bytes (used for validation).
    ///   - count: The number of bytes to be "written" (counted).
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/invalidArgument`` if the arguments are invalid.
    public func write(_ buffer: [UInt8], offset: Int, count: Int) throws {
        try ensureOpen()
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
            throw StreamError.invalidArgument
        }
        let end = currentPosition + count
        if end > currentLength {
            currentLength = end
        }
        currentPosition = end
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
            base = currentLength
        }
        let newPosition = base + offset
        if newPosition < 0 || newPosition > currentLength {
            throw StreamError.outOfRange
        }
        currentPosition = newPosition
        return currentPosition
    }

    /// Clears all buffers for this stream.
    ///
    /// Since a ``MeasuringStream`` does not actually do anything other than
    /// count bytes, this method is a no-op (other than checking that the stream is open).
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

    /// Sets the length of the stream.
    ///
    /// Sets the ``length`` to the specified value and updates ``position``
    /// to the specified value if (and only if) the current position is greater
    /// than the new length value.
    ///
    /// - Parameter length: The desired length of the stream in bytes.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/outOfRange`` if `length` is negative.
    public func setLength(_ length: Int) throws {
        try ensureOpen()
        if length < 0 {
            throw StreamError.outOfRange
        }
        currentLength = length
        if currentPosition > currentLength {
            currentPosition = currentLength
        }
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
