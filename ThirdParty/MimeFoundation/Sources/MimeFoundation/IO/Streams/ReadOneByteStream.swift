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
// ReadOneByteStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A stream wrapper that limits read operations to one byte at a time.
///
/// ``ReadOneByteStream`` wraps another ``MimeStream`` and restricts read operations
/// to return at most one byte per call, regardless of the requested count. This is
/// useful for testing stream handling code with minimal read buffers.
///
/// ## Overview
///
/// This stream wrapper is primarily used for:
/// - Testing parser robustness with minimal read sizes
/// - Debugging stream processing issues
/// - Simulating slow or constrained I/O conditions
///
/// All other stream operations (write, seek, flush) are passed through unchanged
/// to the underlying stream.
///
/// ## Example Usage
///
/// ```swift
/// let baseStream = MemoryStream([0x01, 0x02, 0x03])
/// let oneByteStream = ReadOneByteStream(baseStream)
///
/// var buffer = [UInt8](repeating: 0, count: 10)
/// let bytesRead = try oneByteStream.read(&buffer, offset: 0, count: 10)
/// // bytesRead will be 1, not 10
/// ```
public final class ReadOneByteStream: MimeStream {
    private let baseStream: MimeStream

    /// Initializes a new instance of the ``ReadOneByteStream`` class.
    ///
    /// - Parameter baseStream: The underlying stream to wrap.
    public init(_ baseStream: MimeStream) {
        self.baseStream = baseStream
    }

    /// Gets a value indicating whether the current stream supports reading.
    public var canRead: Bool { baseStream.canRead }

    /// Gets a value indicating whether the current stream supports writing.
    public var canWrite: Bool { baseStream.canWrite }

    /// Gets a value indicating whether the current stream supports seeking.
    public var canSeek: Bool { baseStream.canSeek }

    /// Gets a value indicating whether the current stream can time out.
    public var canTimeout: Bool { baseStream.canTimeout }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    public var readTimeout: Int {
        get { baseStream.readTimeout }
        set { baseStream.readTimeout = newValue }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    public var writeTimeout: Int {
        get { baseStream.writeTimeout }
        set { baseStream.writeTimeout = newValue }
    }

    /// Gets or sets the current position within the stream.
    public var position: Int {
        get { baseStream.position }
        set { baseStream.position = newValue }
    }

    /// Gets the length of the stream in bytes.
    public var length: Int { baseStream.length }

    /// Reads a single byte from the current stream.
    ///
    /// This method overrides the base read behavior to limit reads to at most one byte,
    /// regardless of the `count` parameter. It then delegates to the underlying stream's
    /// read method with a maximum count of 1.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes to store the read data.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin storing data.
    ///   - count: The maximum number of bytes to read (will be clamped to 1).
    ///
    /// - Returns: The total number of bytes read into the buffer (at most 1), or zero if
    ///   the end of the stream has been reached.
    ///
    /// - Throws: Any errors thrown by the underlying stream's read method.
    public func read(_ buffer: inout [UInt8], offset: Int, count: Int) throws -> Int {
        let toRead = min(count, 1)
        return try baseStream.read(&buffer, offset: offset, count: toRead)
    }

    /// Writes a sequence of bytes to the underlying stream.
    ///
    /// This method passes through to the underlying stream without modification.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes containing the data to write.
    ///   - offset: The zero-based byte offset in `buffer` from which to begin copying bytes.
    ///   - count: The number of bytes to be written.
    ///
    /// - Throws: Any errors thrown by the underlying stream's write method.
    public func write(_ buffer: [UInt8], offset: Int, count: Int) throws {
        try baseStream.write(buffer, offset: offset, count: count)
    }

    /// Sets the position within the underlying stream.
    ///
    /// This method passes through to the underlying stream without modification.
    ///
    /// - Parameters:
    ///   - offset: A byte offset relative to the `origin` parameter.
    ///   - origin: A value of type ``SeekOrigin`` indicating the reference point.
    ///
    /// - Returns: The new position within the stream.
    ///
    /// - Throws: Any errors thrown by the underlying stream's seek method.
    public func seek(_ offset: Int, origin: SeekOrigin) throws -> Int {
        try baseStream.seek(offset, origin: origin)
    }

    /// Clears all buffers for the underlying stream.
    ///
    /// This method passes through to the underlying stream without modification.
    ///
    /// - Throws: Any errors thrown by the underlying stream's flush method.
    public func flush() throws {
        try baseStream.flush()
    }

    /// Closes the underlying stream and releases any resources.
    ///
    /// This method passes through to the underlying stream without modification.
    public func close() {
        baseStream.close()
    }
}
