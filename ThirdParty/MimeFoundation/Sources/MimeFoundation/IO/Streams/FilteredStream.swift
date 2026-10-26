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
// FilteredStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A stream which filters data as it is read or written.
///
/// ``FilteredStream`` wraps an underlying source stream and passes data through
/// a chain of ``MimeFilter`` instances as data is read from or written to the stream.
/// This enables transformations like encoding, decoding, or charset conversion to be
/// applied transparently during I/O operations.
///
/// ## Overview
///
/// When reading, data is read from the source stream and passed through each filter
/// in order before being returned to the caller. When writing, data is filtered before
/// being written to the source stream.
///
/// ## Important
///
/// In general, it is not a good idea to manipulate the underlying source stream
/// directly because most filters store important state about previous bytes read
/// from or written to the source stream.
///
/// ## Example Usage
///
/// ```swift
/// // Create a filtered stream with Base64 encoding
/// let outputStream = MemoryBlockStream()
/// let filtered = try FilteredStream(outputStream)
/// try filtered.add(EncoderFilter.create(.base64))
///
/// // Write data - it will be Base64 encoded automatically
/// try filtered.write(rawData, offset: 0, count: rawData.count)
/// try filtered.flush()
/// ```
///
/// ## Seeking
///
/// ``FilteredStream`` does not support seeking because filters maintain internal
/// state based on the sequence of bytes processed. Attempting to seek will throw
/// ``StreamError/notSupported``.
///
/// ## Thread Safety
///
/// ``FilteredStream`` is not thread-safe. External synchronization is required
/// when accessing a filtered stream from multiple threads.
public final class FilteredStream: MimeStream {
    private enum Operation {
        case read
        case write
    }

    private let source: MimeStream
    private var filters: [MimeFilter] = []
    private var lastOp: Operation = .write
    private var filteredBuffer: [UInt8] = []
    private var filteredIndex: Int = 0
    private var filteredLength: Int = 0
    private var readBuffer: [UInt8] = Array(repeating: 0, count: 4096)
    private var flushed = false
    private var closed = false

    /// Initializes a new instance of the ``FilteredStream`` class.
    ///
    /// Creates a filtered stream using the specified source stream. The source stream
    /// will remain open when this ``FilteredStream`` is closed.
    ///
    /// - Parameter source: The underlying stream to filter.
    ///
    /// - Throws: ``StreamError/invalidArgument`` if `source` is `nil`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let memoryStream = MemoryBlockStream()
    /// let filtered = try FilteredStream(memoryStream)
    /// ```
    public init(_ source: MimeStream?) throws {
        guard let source else {
            throw StreamError.invalidArgument
        }
        self.source = source
    }

    /// Gets a value indicating whether the current stream supports reading.
    ///
    /// The ``FilteredStream`` will only support reading if the underlying
    /// source stream supports it.
    public var canRead: Bool { source.canRead }

    /// Gets a value indicating whether the current stream supports writing.
    ///
    /// The ``FilteredStream`` will only support writing if the underlying
    /// source stream supports it.
    public var canWrite: Bool { source.canWrite }

    /// Gets a value indicating whether the current stream supports seeking.
    ///
    /// Seeking is not supported by ``FilteredStream`` because filters maintain
    /// internal state. This always returns `false`.
    public var canSeek: Bool { false }

    /// Gets a value indicating whether the current stream can time out.
    ///
    /// The ``FilteredStream`` will only support timing out if the underlying
    /// source stream supports it.
    public var canTimeout: Bool { source.canTimeout }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to read before timing out.
    ///
    /// Gets or sets the read timeout on the underlying source stream.
    /// If ``canTimeout`` is `false`, this property returns 0 and setting it has no effect.
    public var readTimeout: Int {
        get {
            guard canTimeout else { return 0 }
            return source.readTimeout
        }
        set {
            guard canTimeout else { return }
            source.readTimeout = newValue
        }
    }

    /// Gets or sets a value, in milliseconds, that determines how long the stream
    /// will attempt to write before timing out.
    ///
    /// Gets or sets the write timeout on the underlying source stream.
    /// If ``canTimeout`` is `false`, this property returns 0 and setting it has no effect.
    public var writeTimeout: Int {
        get {
            guard canTimeout else { return 0 }
            return source.writeTimeout
        }
        set {
            guard canTimeout else { return }
            source.writeTimeout = newValue
        }
    }

    /// Gets or sets the current position within the stream.
    ///
    /// Getting and setting the position of a ``FilteredStream`` is not supported
    /// because filters maintain internal state. This always returns 0 and setting
    /// it has no effect.
    public var position: Int {
        get { 0 }
        set { }
    }

    /// Gets the length of the stream in bytes.
    ///
    /// Getting the length of a ``FilteredStream`` is not supported because the
    /// filtered length cannot be determined without processing all data.
    /// This always returns 0.
    public var length: Int { 0 }

    /// Adds a filter to the end of the filter chain.
    ///
    /// Filters are applied in the order they are added. When reading, each filter
    /// processes the data in order. When writing, each filter also processes the
    /// data in order before it is written to the source stream.
    ///
    /// - Parameter filter: The filter to add.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/invalidArgument`` if `filter` is `nil`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let filtered = try FilteredStream(source)
    /// try filtered.add(DecoderFilter.create(.base64))
    /// try filtered.add(CharsetFilter("utf-8", "iso-8859-1"))
    /// ```
    public func add(_ filter: MimeFilter?) throws {
        try ensureOpen()
        guard let filter else {
            throw StreamError.invalidArgument
        }
        filters.append(filter)
    }

    /// Removes a filter from the filter chain.
    ///
    /// - Parameter filter: The filter to remove.
    ///
    /// - Returns: `true` if the filter was found and removed; otherwise, `false`.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/invalidArgument`` if `filter` is `nil`.
    public func remove(_ filter: MimeFilter?) throws -> Bool {
        try ensureOpen()
        guard let filter else {
            throw StreamError.invalidArgument
        }
        if let index = filters.firstIndex(where: { $0 === filter }) {
            filters.remove(at: index)
            return true
        }
        return false
    }

    /// Determines whether the filtered stream contains the specified filter.
    ///
    /// - Parameter filter: The filter to locate.
    ///
    /// - Returns: `true` if the filter is in the chain; otherwise, `false`.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   or ``StreamError/invalidArgument`` if `filter` is `nil`.
    public func contains(_ filter: MimeFilter?) throws -> Bool {
        try ensureOpen()
        guard let filter else {
            throw StreamError.invalidArgument
        }
        return filters.contains { $0 === filter }
    }

    /// Reads a sequence of bytes from the stream and advances the position
    /// within the stream by the number of bytes read.
    ///
    /// Reads data from the source stream and passes it through each filter
    /// before returning the result. If switching from write to read mode,
    /// all filters are reset.
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
            print("FilteredStream.write invalidArgument offset=\(offset) count=\(count) buffer.count=\(buffer.count)")
            throw StreamError.invalidArgument
        }
        if count == 0 {
            return 0
        }

        if lastOp != .read {
            resetFilters()
            filteredBuffer = []
            filteredIndex = 0
            filteredLength = 0
            flushed = false
            lastOp = .read
        }

        var written = 0
        while written < count {
            if filteredIndex < filteredLength {
                let available = min(count - written, filteredLength - filteredIndex)
                buffer.replaceSubrange((offset + written)..<(offset + written + available),
                                       with: filteredBuffer[filteredIndex..<(filteredIndex + available)])
                filteredIndex += available
                written += available
                continue
            }

            if flushed {
                break
            }

            let nread = try source.read(&readBuffer, offset: 0, count: readBuffer.count)
            if nread == 0 {
                applyFilters(input: [], startIndex: 0, length: 0, flush: true)
                flushed = true
            } else {
                applyFilters(input: readBuffer, startIndex: 0, length: nread, flush: false)
            }

            if filteredLength == 0 && flushed {
                break
            }
        }

        return written
    }

    /// Writes a sequence of bytes to the stream and advances the current
    /// position within this stream by the number of bytes written.
    ///
    /// Filters the provided buffer through each filter in the chain before
    /// writing the result to the underlying source stream. If switching from
    /// read to write mode, all filters are reset.
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
            print("FilteredStream.write invalidArgument offset=\(offset) count=\(count) buffer.count=\(buffer.count)")
            throw StreamError.invalidArgument
        }
        if count == 0 {
            return
        }

        if lastOp != .write {
            resetFilters()
            lastOp = .write
        }

        var outputBuffer = buffer
        var outputIndex = offset
        var outputLength = count

        for filter in filters {
            outputBuffer = filter.filter(outputBuffer, startIndex: outputIndex, length: outputLength, outputIndex: &outputIndex, outputLength: &outputLength)
            if outputIndex < 0 || outputLength < 0 || outputIndex + outputLength > outputBuffer.count {
                print("FilteredStream.write invalid filter output: \(type(of: filter)) outputIndex=\(outputIndex) outputLength=\(outputLength) buffer.count=\(outputBuffer.count)")
            }
        }

        if outputLength > 0 {
            try source.write(outputBuffer, offset: outputIndex, count: outputLength)
        }
    }

    /// Sets the position within the current stream.
    ///
    /// Seeking is not supported by ``FilteredStream`` because filters maintain
    /// internal state that depends on the sequence of bytes processed.
    ///
    /// - Parameters:
    ///   - offset: A byte offset relative to the `origin` parameter.
    ///   - origin: A value of type ``SeekOrigin`` indicating the reference point
    ///     used to obtain the new position.
    ///
    /// - Throws: Always throws ``StreamError/notSupported``.
    public func seek(_ offset: Int, origin: SeekOrigin) throws -> Int {
        throw StreamError.notSupported
    }

    /// Clears all buffers for this stream and causes any buffered data to be written
    /// to the underlying device.
    ///
    /// Flushes the state of all filters, writing any remaining output to the underlying
    /// source stream, and then flushes the source stream itself.
    ///
    /// This method is particularly important when writing, as many filters buffer data
    /// internally. Calling ``flush()`` ensures all data is written to the destination.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed.
    public func flush() throws {
        try ensureOpen()
        if lastOp == .write {
            var outputBuffer: [UInt8] = []
            var outputIndex = 0
            var outputLength = 0
            var startIndex = 0
            var length = 0

            for filter in filters {
                if outputBuffer.isEmpty {
                    outputBuffer = filter.flush([], startIndex: startIndex, length: length, outputIndex: &outputIndex, outputLength: &outputLength)
                } else {
                    outputBuffer = filter.flush(outputBuffer, startIndex: outputIndex, length: outputLength, outputIndex: &outputIndex, outputLength: &outputLength)
                }
                startIndex = outputIndex
                length = outputLength
            }

            if outputLength > 0 {
                try source.write(outputBuffer, offset: outputIndex, count: outputLength)
            }
        }
        try source.flush()
    }

    /// Closes the stream and releases any resources associated with it.
    ///
    /// The underlying source stream is not closed. After calling this method,
    /// any further operations on the stream will throw ``StreamError/closed``.
    public func close() {
        closed = true
    }

    private func applyFilters(input: [UInt8], startIndex: Int, length: Int, flush: Bool) {
        var buffer = input
        var outIndex = startIndex
        var outLength = length

        for filter in filters {
            if flush {
                buffer = filter.flush(buffer, startIndex: outIndex, length: outLength, outputIndex: &outIndex, outputLength: &outLength)
            } else {
                buffer = filter.filter(buffer, startIndex: outIndex, length: outLength, outputIndex: &outIndex, outputLength: &outLength)
            }
        }

        filteredBuffer = buffer
        filteredIndex = outIndex
        filteredLength = outIndex + outLength
    }

    private func resetFilters() {
        for filter in filters {
            filter.reset()
        }
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
