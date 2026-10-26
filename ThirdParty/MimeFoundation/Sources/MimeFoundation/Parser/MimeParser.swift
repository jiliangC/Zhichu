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
// MimeParser.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during MIME parsing.
public enum MimeParserError: Error, Equatable, Sendable {
}

/// A MIME message and entity parser.
///
/// A MIME parser is used to parse ``MimeMessage`` and ``MimeEntity`` objects from arbitrary streams.
///
/// ## Overview
///
/// The `MimeParser` class provides methods for parsing MIME messages, entities, and headers from
/// a stream. It supports both standard MIME format and the Unix mbox format for parsing multiple
/// messages from a single stream.
///
/// ## Example Usage
///
/// ```swift
/// // Parse a single message
/// let stream = MemoryStream(data, writable: false)
/// let parser = try MimeParser(stream)
/// let message = try parser.parseMessage()
///
/// // Parse messages from an mbox file
/// let mboxStream = MemoryStream(mboxData, writable: false)
/// let mboxParser = try MimeParser(mboxStream, .mbox)
/// while !mboxParser.isEndOfStream {
///     let message = try mboxParser.parseMessage()
///     // Process message...
/// }
/// ```
open class MimeParser {
    /// The parser options used when parsing MIME content.
    ///
    /// Gets or sets the parser options. These options control various aspects of parsing
    /// behavior such as RFC compliance modes and content length handling.
    public var options: ParserOptions

    /// The format of the input stream.
    ///
    /// Gets a value indicating whether the parser was initialized to parse a single entity
    /// (``MimeFormat/entity``) or an mbox stream containing multiple messages (``MimeFormat/mbox``).
    public private(set) var format: MimeFormat

    /// A value indicating whether the parser has reached the end of the input stream.
    ///
    /// When parsing mbox-formatted streams, this property can be used to determine when
    /// all messages have been parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// while !parser.isEndOfStream {
    ///     let message = try parser.parseMessage()
    ///     // Process message...
    /// }
    /// ```
    public private(set) var isEndOfStream: Bool = false

    /// The current position of the parser within the stream.
    ///
    /// Gets the current stream offset indicating how many bytes have been consumed.
    public var position: Int { currentOffset }

    private var data: [UInt8] = []
    private var lineMap = LineMap([])
    private var mboxMarkers: [MboxMarker] = []
    private var currentOffset: Int = 0
    private var currentMarkerIndex: Int = 0

    /// Initializes a new instance of the `MimeParser` class.
    ///
    /// Creates a new `MimeParser` that will parse the specified stream using the default parser options.
    ///
    /// - Parameters:
    ///   - stream: The stream to parse.
    ///   - format: The format of the stream. Defaults to ``MimeFormat/default``.
    /// - Throws: An error if the stream cannot be read.
    public init(_ stream: MimeStream, _ format: MimeFormat = .default) throws {
        self.options = ParserOptions.default
        self.format = format
        try setStream(stream, format)
    }

    /// Initializes a new instance of the `MimeParser` class with custom parser options.
    ///
    /// Creates a new `MimeParser` that will parse the specified stream using the provided parser options.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - stream: The stream to parse.
    ///   - format: The format of the stream. Defaults to ``MimeFormat/default``.
    /// - Throws: An error if the stream cannot be read.
    public init(_ options: ParserOptions, _ stream: MimeStream, _ format: MimeFormat = .default) throws {
        self.options = options
        self.format = format
        try setStream(stream, format)
    }

    /// Sets the stream to parse.
    ///
    /// Resets the parser state and prepares to parse the specified stream.
    ///
    /// - Parameters:
    ///   - stream: The stream to parse.
    ///   - format: The format of the stream. Defaults to ``MimeFormat/default``.
    /// - Throws: An error if the stream cannot be read.
    public func setStream(_ stream: MimeStream, _ format: MimeFormat = .default) throws {
        self.format = format
        self.data = try readAllBytes(from: stream)
        self.lineMap = LineMap(data)
        self.currentOffset = 0
        self.currentMarkerIndex = 0
        self.isEndOfStream = data.isEmpty
        if format == .mbox {
            self.mboxMarkers = scanMboxMarkers()
        } else {
            self.mboxMarkers = []
        }
    }

    /// Parses a list of headers from the stream.
    ///
    /// Parses headers from the current position in the stream until a blank line
    /// or end of stream is encountered.
    ///
    /// - Returns: The parsed list of headers.
    /// - Throws: ``ParseException`` if there was an error parsing the headers.
    public func parseHeaders() throws -> HeaderList {
        if isEndOfStream {
            return HeaderList()
        }
        let bytes = data[currentOffset..<data.count]
        if shouldThrowForTruncatedHeaderName(bytes) {
            throw ParseException("Invalid header.", tokenIndex: currentOffset, errorIndex: currentOffset)
        }
        let (headers, bodyBytes) = MimeMessage.parseHeaders(bytes)
        currentOffset += bytes.count - bodyBytes.count
        if currentOffset >= data.count {
            isEndOfStream = true
        }
        return headers
    }

    /// Asynchronously parses a list of headers from the stream.
    ///
    /// Parses headers from the current position in the stream until a blank line
    /// or end of stream is encountered.
    ///
    /// - Returns: The parsed list of headers.
    /// - Throws: ``ParseException`` if there was an error parsing the headers.
    public func parseHeadersAsync() async throws -> HeaderList {
        try parseHeaders()
    }

    /// Parses a message from the stream.
    ///
    /// Parses a complete MIME message from the stream. If the parser was initialized
    /// with ``MimeFormat/mbox``, this method will parse the next message from the mbox stream.
    ///
    /// - Returns: The parsed message.
    /// - Throws: ``ParseException`` if there was an error parsing the message.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let parser = try MimeParser(stream)
    /// let message = try parser.parseMessage()
    /// print(message.subject ?? "No subject")
    /// ```
    public func parseMessage() throws -> MimeMessage {
        let range = try nextMessageRange()
        let messageBytesSlice = data[range.start..<range.end]
        if messageBytesSlice.isEmpty {
            if format == .mbox {
                let message = MimeMessage(addDefaults: false)
                currentOffset = range.end
                if currentOffset >= data.count {
                    isEndOfStream = true
                }
                return message
            }
            throw ParseException("End of stream.", tokenIndex: currentOffset, errorIndex: currentOffset)
        }
        let stripped = try stripByteOrderMarkIfNeeded(messageBytesSlice)
        try validateHeaderStart(in: stripped, errorMessage: "Failed to parse message headers.")
        let stream = MemoryStream(Array(stripped), writable: false)
        let message = try MimeMessage.load(options, stream)
        currentOffset = range.end
        if currentOffset >= data.count {
            isEndOfStream = true
        }
        return message
    }

    /// Asynchronously parses a message from the stream.
    ///
    /// Parses a complete MIME message from the stream. If the parser was initialized
    /// with ``MimeFormat/mbox``, this method will parse the next message from the mbox stream.
    ///
    /// - Returns: The parsed message.
    /// - Throws: ``ParseException`` if there was an error parsing the message.
    public func parseMessageAsync() async throws -> MimeMessage {
        try parseMessage()
    }

    /// Parses an entity from the stream.
    ///
    /// Parses a MIME entity from the stream. Unlike ``parseMessage()``, this method
    /// does not expect a message envelope and parses just the entity content.
    ///
    /// - Returns: The parsed entity.
    /// - Throws: ``ParseException`` if there was an error parsing the entity.
    public func parseEntity() throws -> MimeEntity {
        let bytes = data[currentOffset..<data.count]
        if bytes.isEmpty {
            throw ParseException("End of stream.", tokenIndex: currentOffset, errorIndex: currentOffset)
        }
        let stripped = try stripByteOrderMarkIfNeeded(bytes)
        try validateHeaderStart(in: stripped, errorMessage: "Failed to parse entity headers.")
        // MemoryStream needs Array or Data, so we must copy here until MemoryStream supports slices or we have a SliceStream
        let stream = MemoryStream(Array(stripped), writable: false)
        let entity = try MimeEntity.load(options, stream)
        currentOffset = data.count
        isEndOfStream = true
        return entity
    }

    /// Asynchronously parses an entity from the stream.
    ///
    /// Parses a MIME entity from the stream. Unlike ``parseMessageAsync()``, this method
    /// does not expect a message envelope and parses just the entity content.
    ///
    /// - Returns: The parsed entity.
    /// - Throws: ``ParseException`` if there was an error parsing the entity.
    public func parseEntityAsync() async throws -> MimeEntity {
        try parseEntity()
    }
}

// MARK: - Parsing helpers

private extension MimeParser {
    func shouldThrowForTruncatedHeaderName(_ bytes: ArraySlice<UInt8>) -> Bool {
        guard !bytes.isEmpty else { return false }
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == 0x0D || byte == 0x0A {
                return false
            }
            index += 1
        }
        return !bytes.contains(0x3A)
    }

    func stripByteOrderMarkIfNeeded(_ bytes: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
        guard bytes.count >= 2 else {
            return bytes
        }
        let start = bytes.startIndex
        if bytes[start] == 0xEF && bytes[start + 1] == 0xBB {
            guard bytes.count >= 3 else {
                throw ParseException("Invalid byte order mark.", tokenIndex: currentOffset, errorIndex: currentOffset)
            }
            guard bytes[start + 2] == 0xBF else {
                throw ParseException("Invalid byte order mark.", tokenIndex: currentOffset, errorIndex: currentOffset)
            }
            if bytes.count == 3 {
                throw ParseException("End of stream.", tokenIndex: currentOffset, errorIndex: currentOffset)
            }
            return bytes[(start + 3)..<bytes.endIndex]
        }
        return bytes
    }

    func validateHeaderStart(in bytes: ArraySlice<UInt8>, errorMessage: String) throws {
        guard !bytes.isEmpty else {
            throw ParseException("End of stream.", tokenIndex: currentOffset, errorIndex: currentOffset)
        }
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == 0x0D || byte == 0x0A {
                break
            }
            index += 1
        }
        if index == bytes.startIndex {
            return
        }
        if !bytes[bytes.startIndex..<index].contains(0x3A) {
            throw ParseException(errorMessage, tokenIndex: currentOffset, errorIndex: currentOffset)
        }
    }

    func readAllBytes(from stream: MimeStream) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data: [UInt8] = []
        _ = try stream.seek(0, origin: .begin)
        while true {
            let read = try stream.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }

    func scanMboxMarkers() -> [MboxMarker] {
        let markerBytes = Array("From ".utf8)
        var markers: [MboxMarker] = []
        for (index, line) in lineMap.lines.enumerated() {
            let length = line.end - line.start
            if length < markerBytes.count {
                continue
            }
            let slice = data[line.start..<line.end]
            if slice.starts(with: markerBytes) {
                markers.append(MboxMarker(start: line.start, lineIndex: index, lineEnd: line.end, lineBreakLength: line.breakLength))
            }
        }
        return markers
    }

    func nextMessageRange() throws -> (start: Int, end: Int) {
        if isEndOfStream || currentOffset >= data.count {
            isEndOfStream = true
            throw ParseException("End of stream.", tokenIndex: currentOffset, errorIndex: currentOffset)
        }

        switch format {
        case .entity:
            return (currentOffset, data.count)
        case .mbox:
            var markerIndex = currentMarkerIndex
            while markerIndex < mboxMarkers.count && mboxMarkers[markerIndex].start < currentOffset {
                markerIndex += 1
            }
            if markerIndex >= mboxMarkers.count {
                throw ParseException("Failed to find mbox From marker.", tokenIndex: currentOffset, errorIndex: currentOffset)
            }
            let marker = mboxMarkers[markerIndex]
            let markerLength = marker.lineEnd - marker.start
            if marker.lineBreakLength == 0 || markerLength > 4096 {
                throw ParseException("Invalid mbox marker.", tokenIndex: marker.start, errorIndex: marker.start)
            }
            let messageStart = marker.lineEnd + marker.lineBreakLength
            var nextMarkerIndex = markerIndex + 1
            var messageEnd = data.count
            if options.respectContentLength, let contentLength = parseContentLength(startOffset: messageStart) {
                let headerEndIndex = headerBodySeparatorOffset(in: data, startOffset: messageStart) ?? messageStart
                let bodyStart = headerEndIndex
                let contentEnd = min(bodyStart + contentLength, data.count)
                while nextMarkerIndex < mboxMarkers.count && mboxMarkers[nextMarkerIndex].start < contentEnd {
                    nextMarkerIndex += 1
                }
                if nextMarkerIndex < mboxMarkers.count {
                    messageEnd = adjustedEndOffset(beforeLineIndex: mboxMarkers[nextMarkerIndex].lineIndex)
                } else {
                    messageEnd = data.count
                }
            } else if nextMarkerIndex < mboxMarkers.count {
                messageEnd = adjustedEndOffset(beforeLineIndex: mboxMarkers[nextMarkerIndex].lineIndex)
            }
            if messageEnd < messageStart {
                messageEnd = messageStart
            }
            currentMarkerIndex = nextMarkerIndex
            return (messageStart, messageEnd)
        }
    }

    func headerBodySeparatorOffset(in data: [UInt8], startOffset: Int) -> Int? {
        if startOffset >= data.count {
            return nil
        }
        var index = startOffset
        var newlineCount = 0
        while index < data.count {
            let byte = data[index]
            if byte == 0x0D {
                if index + 1 < data.count, data[index + 1] == 0x0A {
                    newlineCount += 1
                    index += 2
                } else {
                    newlineCount += 1
                    index += 1
                }
            } else if byte == 0x0A {
                newlineCount += 1
                index += 1
            } else {
                newlineCount = 0
                index += 1
            }
            if newlineCount >= 2 {
                return index
            }
        }
        return nil
    }

    func parseContentLength(startOffset: Int) -> Int? {
        let bytes = data[startOffset..<data.count]
        let (headers, _) = MimeMessage.parseHeaders(bytes)
        guard let value = headers[.contentLength] else {
            return nil
        }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func adjustedEndOffset(beforeLineIndex lineIndex: Int) -> Int {
        if lineIndex <= 0 {
            return lineMap.lines.first?.start ?? 0
        }
        let previous = lineMap.lines[lineIndex - 1]
        return previous.end
    }
}
