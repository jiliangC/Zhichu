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
// MimeStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Specifies the position in a stream to use for seeking.
///
/// The ``SeekOrigin`` enum is used in conjunction with the ``MimeStream/seek(_:origin:)``
/// method to specify the reference point for setting the stream position.
public enum SeekOrigin: Sendable {
    /// Specifies the beginning of a stream.
    case begin

    /// Specifies the current position within a stream.
    case current

    /// Specifies the end of a stream.
    case end
}

/// Represents errors that can occur during stream operations.
///
/// ``StreamError`` encapsulates the common error conditions that can arise
/// when performing I/O operations on streams.
public enum StreamError: Error, Sendable {
    /// The operation is not supported by the stream.
    ///
    /// This error is thrown when attempting an operation that the stream
    /// does not support, such as reading from a write-only stream.
    case notSupported

    /// One or more arguments are invalid.
    ///
    /// This error is thrown when invalid parameters are passed to a stream operation,
    /// such as a negative offset or a count that exceeds the buffer size.
    case invalidArgument

    /// The specified position is outside the valid range.
    ///
    /// This error is thrown when attempting to seek to a position before
    /// the beginning or after the end of the stream.
    case outOfRange

    /// The stream has been closed.
    ///
    /// This error is thrown when attempting to perform an operation
    /// on a stream that has already been closed.
    case closed
}

/// A protocol that provides a generic view of a sequence of bytes.
///
/// ``MimeStream`` provides the fundamental interface for reading and writing data
/// in a streaming fashion. It supports basic I/O operations including reading,
/// writing, seeking, and flushing.
///
/// ## Overview
///
/// Streams are used throughout the MIME processing pipeline for handling content
/// data efficiently. Different stream implementations provide various capabilities:
///
/// - ``MemoryStream``: Stores data in memory with full read/write/seek support
/// - ``MemoryBlockStream``: Memory stream optimized to avoid array copying
/// - ``FilteredStream``: Applies transformations as data passes through
/// - ``BoundStream``: Provides a view into a subset of another stream
/// - ``ChainedStream``: Combines multiple streams into one continuous stream
/// - ``MeasuringStream``: Tracks the number of bytes written without storing data
///
/// ## Implementing MimeStream
///
/// When implementing a custom stream, check the capability properties (``canRead``,
/// ``canWrite``, ``canSeek``) before attempting operations. Throw ``StreamError/notSupported``
/// if an unsupported operation is attempted.
public protocol MimeStream: AnyObject {
    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// If a class derived from ``MimeStream`` does not support reading, calls to
    /// ``read(_:offset:count:)`` will throw ``StreamError/notSupported``.
    var canRead: Bool { get }

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// If a class derived from ``MimeStream`` does not support writing, calls to
    /// ``write(_:offset:count:)`` will throw ``StreamError/notSupported``.
    var canWrite: Bool { get }

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// If a class derived from ``MimeStream`` does not support seeking, calls to
    /// ``seek(_:origin:)`` will throw ``StreamError/notSupported``.
    var canSeek: Bool { get }

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// The ``canTimeout`` property indicates whether read and write operations
    /// can time out. For streams that do not support timeouts, this returns `false`.
    var canTimeout: Bool { get }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// A value of 0 indicates that the read operation does not time out.
    /// This property is only meaningful if ``canTimeout`` returns `true`.
    var readTimeout: Int { get set }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// A value of 0 indicates that the write operation does not time out.
    /// This property is only meaningful if ``canTimeout`` returns `true`.
    var writeTimeout: Int { get set }

    /// Gets or sets the position within the current stream.
    ///
    /// The position is the number of bytes from the beginning of the stream.
    /// Setting the position is equivalent to calling ``seek(_:origin:)``
    /// with ``SeekOrigin/begin``.
    ///
    /// - Note: Seeking is only supported if ``canSeek`` returns `true`.
    var position: Int { get set }

    /// Gets the length in bytes of the stream.
    ///
    /// For streams with a finite length, this returns the total number of bytes.
    /// Some streams may not have a well-defined length and will throw
    /// ``StreamError/notSupported``.
    var length: Int { get }

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
    /// - Throws: ``StreamError/notSupported`` if the stream does not support reading,
    ///   ``StreamError/invalidArgument`` if the arguments are invalid,
    ///   or ``StreamError/closed`` if the stream has been closed.
    func read(_ buffer: inout [UInt8], offset: Int, count: Int) throws -> Int

    /// Writes a sequence of bytes to the current stream and advances the current
    /// position within this stream by the number of bytes written.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes containing the data to write.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin
    ///     copying bytes to the current stream.
    ///   - count: The number of bytes to be written to the current stream.
    ///
    /// - Throws: ``StreamError/notSupported`` if the stream does not support writing,
    ///   ``StreamError/invalidArgument`` if the arguments are invalid,
    ///   or ``StreamError/closed`` if the stream has been closed.
    func write(_ buffer: [UInt8], offset: Int, count: Int) throws

    /// Sets the position within the current stream.
    ///
    /// - Parameters:
    ///   - offset: A byte offset relative to the `origin` parameter.
    ///   - origin: A value of type ``SeekOrigin`` indicating the reference point
    ///     used to obtain the new position.
    ///
    /// - Returns: The new position within the current stream.
    ///
    /// - Throws: ``StreamError/notSupported`` if the stream does not support seeking,
    ///   ``StreamError/outOfRange`` if the resulting position would be invalid,
    ///   or ``StreamError/closed`` if the stream has been closed.
    func seek(_ offset: Int, origin: SeekOrigin) throws -> Int

    /// Clears all buffers for this stream and causes any buffered data to be written
    /// to the underlying device.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    func flush() throws

    /// Closes the current stream and releases any resources associated with it.
    ///
    /// After closing a stream, any further operations on it will throw
    /// ``StreamError/closed``.
    func close()
}

// MARK: - Capability Marker Protocols

/// A stream that guarantees read capability at compile time.
///
/// Conforming types declare that their `canRead` property always returns `true`.
/// This enables APIs that require readable streams to be non-throwing when
/// the stream type is known at compile time.
///
/// ## Conforming to ReadableStream
///
/// Types should only conform to `ReadableStream` if they unconditionally support
/// reading. The `canRead` property must always return `true`:
///
/// ```swift
/// public final class MyReadableStream: MimeStream, ReadableStream {
///     public var canRead: Bool { true }  // Must always be true
///     // ...
/// }
/// ```
///
/// ## Example Usage
///
/// ```swift
/// func process(_ stream: some ReadableStream) {
///     // No need to check canRead - it's guaranteed by the type
///     var buffer = [UInt8](repeating: 0, count: 1024)
///     let bytesRead = try stream.read(&buffer, offset: 0, count: buffer.count)
/// }
/// ```
public protocol ReadableStream: MimeStream {}

/// A stream that guarantees write capability at compile time.
///
/// Conforming types declare that their `canWrite` property always returns `true`.
/// This enables APIs that require writable streams to be non-throwing when
/// the stream type is known at compile time.
///
/// ## Conforming to WritableStream
///
/// Types should only conform to `WritableStream` if they unconditionally support
/// writing. The `canWrite` property must always return `true`:
///
/// ```swift
/// public final class MyWritableStream: MimeStream, WritableStream {
///     public var canWrite: Bool { true }  // Must always be true
///     // ...
/// }
/// ```
public protocol WritableStream: MimeStream {}

/// A stream that guarantees seek capability at compile time.
///
/// Conforming types declare that their `canSeek` property always returns `true`.
/// This enables APIs that require seekable streams to be non-throwing when
/// the stream type is known at compile time.
///
/// ## Conforming to SeekableStream
///
/// Types should only conform to `SeekableStream` if they unconditionally support
/// seeking. The `canSeek` property must always return `true`:
///
/// ```swift
/// public final class MySeekableStream: MimeStream, SeekableStream {
///     public var canSeek: Bool { true }  // Must always be true
///     // ...
/// }
/// ```
public protocol SeekableStream: MimeStream {}

/// A stream suitable for use as MIME content storage.
///
/// This typealias combines `ReadableStream` and `SeekableStream`, representing
/// streams that can be used to store MIME content. MIME content requires both
/// reading (to access the content) and seeking (to reset position for re-reading).
///
/// ## Example Usage
///
/// ```swift
/// // MemoryStream conforms to ContentStream, so this doesn't throw
/// let content = MimeContent(MemoryStream(data))
///
/// // For unknown stream types, use the throwing initializer
/// let content = try MimeContent(stream: unknownStream)
/// ```
///
/// ## Conforming Types
///
/// - `MemoryStream`: Always readable and seekable
/// - `MemoryBlockStream`: Always readable, writable, and seekable
public typealias ContentStream = ReadableStream & SeekableStream
