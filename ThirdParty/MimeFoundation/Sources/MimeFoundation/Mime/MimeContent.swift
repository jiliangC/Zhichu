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
// MimeContent.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with MIME content.
public enum MimeContentError: Error, Sendable {
    /// The stream does not support reading.
    case streamNotReadable

    /// The stream does not support seeking.
    case streamNotSeekable

    /// The content has been disposed.
    case disposed
}

/// Encapsulates a content stream used by `MimePart`.
///
/// A `MimeContent` encapsulates the content stream of a MIME part and provides
/// methods to read, write, and decode the content. The content is stored in its
/// encoded form (e.g., base64) and can be decoded when accessed.
public final class MimeContent {
    private static let bufferLength = 4096

    /// The encoding of the content stream.
    ///
    /// The encoding is used when decoding the content stream. For example,
    /// if the encoding is `.base64`, the stream will be base64-decoded when
    /// reading the content.
    public let encoding: ContentEncoding

    /// The new line format detected in the content, if any.
    public var newLineFormat: NewLineFormat?

    private var stream: MimeStream?

    /// Creates content from a stream with statically-known read and seek capabilities.
    ///
    /// This initializer cannot fail since the stream type guarantees the required capabilities.
    ///
    /// - Parameters:
    ///   - stream: A stream that conforms to `ContentStream` (readable and seekable).
    ///   - encoding: The content transfer encoding of the stream data.
    public init(_ stream: some ContentStream, encoding: ContentEncoding = .default) {
        self.encoding = encoding
        self.stream = stream
    }

    /// Creates content from any MimeStream, throwing if required capabilities are missing.
    ///
    /// Prefer using the non-throwing initializer with `ContentStream` when possible.
    ///
    /// - Parameters:
    ///   - stream: The stream containing the content.
    ///   - encoding: The content transfer encoding of the stream data.
    /// - Throws: `MimeContentError.streamNotReadable` if the stream cannot be read,
    ///           or `MimeContentError.streamNotSeekable` if the stream cannot seek.
    public init(stream: MimeStream, encoding: ContentEncoding = .default) throws {
        guard stream.canRead else {
            throw MimeContentError.streamNotReadable
        }
        guard stream.canSeek else {
            throw MimeContentError.streamNotSeekable
        }
        self.encoding = encoding
        self.stream = stream
    }

    /// Opens the content stream for reading and decodes it.
    ///
    /// Opens a stream that will decode the content using the encoding specified
    /// when the `MimeContent` was created. For example, if the encoding is `.base64`,
    /// reading from the returned stream will return the decoded bytes.
    ///
    /// - Returns: A stream that decodes the content as it is read.
    /// - Throws: `MimeContentError.disposed` if the content has been disposed.
    public func open() throws -> MimeStream {
        try checkDisposed()
        guard let stream else {
            throw MimeContentError.disposed
        }
        _ = try stream.seek(0, origin: .begin)
        let filtered = try FilteredStream(stream)
        let filter = DecoderFilter.create(encoding)
        _ = try filtered.add(filter)
        return filtered
    }

    /// Writes the raw (encoded) content to the destination stream.
    ///
    /// Copies the raw encoded content to the destination without decoding it.
    /// Use `decodeTo(_:)` if you need the decoded content.
    ///
    /// - Parameter destination: The stream to write to.
    /// - Throws: `MimeContentError.disposed` if the content has been disposed.
    public func writeTo(_ destination: MimeStream) throws {
        try checkDisposed()
        guard let source = stream else {
            throw MimeContentError.disposed
        }
        _ = try source.seek(0, origin: .begin)

        var buffer = [UInt8](repeating: 0, count: MimeContent.bufferLength)
        while true {
            let read = try source.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            try destination.write(buffer, offset: 0, count: read)
        }
    }

    /// Asynchronously writes the raw (encoded) content to the destination stream.
    ///
    /// Copies the raw encoded content to the destination without decoding it.
    /// Use `decodeToAsync(_:)` if you need the decoded content.
    ///
    /// - Parameter destination: The stream to write to.
    /// - Throws: `MimeContentError.disposed` if the content has been disposed.
    public func writeToAsync(_ destination: MimeStream) async throws {
        try Task.checkCancellation()
        try checkDisposed()
        guard let source = stream else {
            throw MimeContentError.disposed
        }
        _ = try source.seek(0, origin: .begin)

        var buffer = [UInt8](repeating: 0, count: MimeContent.bufferLength)
        while true {
            try Task.checkCancellation()
            let read = try source.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            try destination.write(buffer, offset: 0, count: read)
        }
    }

    /// Decodes the content and writes it to the destination stream.
    ///
    /// Decodes the content using the encoding specified when the `MimeContent`
    /// was created and writes the decoded bytes to the destination.
    ///
    /// - Parameter destination: The stream to write decoded content to.
    /// - Throws: `MimeContentError.disposed` if the content has been disposed.
    public func decodeTo(_ destination: MimeStream) throws {
        try checkDisposed()
        guard let source = stream else {
            throw MimeContentError.disposed
        }
        _ = try source.seek(0, origin: .begin)

        let filtered = try FilteredStream(source)
        let filter = DecoderFilter.create(encoding)
        _ = try filtered.add(filter)

        var buffer = [UInt8](repeating: 0, count: MimeContent.bufferLength)
        while true {
            let read = try filtered.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            try destination.write(buffer, offset: 0, count: read)
        }
    }

    /// Asynchronously decodes the content and writes it to the destination stream.
    ///
    /// Decodes the content using the encoding specified when the `MimeContent`
    /// was created and writes the decoded bytes to the destination.
    ///
    /// - Parameter destination: The stream to write decoded content to.
    /// - Throws: `MimeContentError.disposed` if the content has been disposed.
    public func decodeToAsync(_ destination: MimeStream) async throws {
        try Task.checkCancellation()
        try checkDisposed()
        guard let source = stream else {
            throw MimeContentError.disposed
        }
        _ = try source.seek(0, origin: .begin)

        let filtered = try FilteredStream(source)
        let filter = DecoderFilter.create(encoding)
        _ = try filtered.add(filter)

        var buffer = [UInt8](repeating: 0, count: MimeContent.bufferLength)
        while true {
            try Task.checkCancellation()
            let read = try filtered.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            try destination.write(buffer, offset: 0, count: read)
        }
    }

    private func checkDisposed() throws {
        if stream == nil {
            throw MimeContentError.disposed
        }
    }
}
