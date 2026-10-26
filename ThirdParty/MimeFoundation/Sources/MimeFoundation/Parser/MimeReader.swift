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
// MimeReader.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during MIME reading.
public enum MimeReaderError: Error, Equatable, Sendable {
}

/// Information about a line in the parsed content.
internal struct LineInfo {
    /// The byte offset where the line starts.
    let start: Int
    /// The byte offset where the line content ends (before any line break).
    let end: Int
    /// The length of the line break sequence (1 for LF, 2 for CRLF, 0 for last line without break).
    let breakLength: Int
}

/// A map of lines in parsed content for efficient line number lookups.
internal struct LineMap {
    /// The array of line information.
    let lines: [LineInfo]

    /// Initializes a line map from the given byte data.
    ///
    /// - Parameter data: The byte data to create a line map for.
    init(_ data: [UInt8]) {
        #if MIME_UseUnsafe
        self.lines = data.withUnsafeBufferPointer { buffer in
            var items: [LineInfo] = []
            items.reserveCapacity(data.count / 40) // heuristic

            guard let baseAddress = buffer.baseAddress else {
                if data.isEmpty {
                    return [LineInfo(start: 0, end: 0, breakLength: 0)]
                }
                return []
            }

            let count = buffer.count
            var index = 0
            var lineStart = 0

            while index < count {
                let byte = baseAddress[index]

                if byte == 0x0D { // CR
                    if index + 1 < count && baseAddress[index + 1] == 0x0A { // CRLF
                        items.append(LineInfo(start: lineStart, end: index, breakLength: 2))
                        index += 2
                        lineStart = index
                    } else { // CR only
                        items.append(LineInfo(start: lineStart, end: index, breakLength: 1))
                        index += 1
                        lineStart = index
                    }
                } else if byte == 0x0A { // LF
                    items.append(LineInfo(start: lineStart, end: index, breakLength: 1))
                    index += 1
                    lineStart = index
                } else {
                    index += 1
                }
            }

            if lineStart <= count {
                items.append(LineInfo(start: lineStart, end: count, breakLength: 0))
            }

            return items
        }
        #else
        var items: [LineInfo] = []
        var index = 0
        var lineStart = 0
        while index < data.count {
            let byte = data[index]
            if byte == 0x0D {
                if index + 1 < data.count, data[index + 1] == 0x0A {
                    items.append(LineInfo(start: lineStart, end: index, breakLength: 2))
                    index += 2
                    lineStart = index
                    continue
                } else {
                    items.append(LineInfo(start: lineStart, end: index, breakLength: 1))
                    index += 1
                    lineStart = index
                    continue
                }
            }
            if byte == 0x0A {
                items.append(LineInfo(start: lineStart, end: index, breakLength: 1))
                index += 1
                lineStart = index
                continue
            }
            index += 1
        }
        if lineStart <= data.count {
            items.append(LineInfo(start: lineStart, end: data.count, breakLength: 0))
        }
        self.lines = items
        #endif
    }

    /// Gets the line number (1-based) for the given byte offset.
    ///
    /// - Parameter offset: The byte offset.
    /// - Returns: The line number containing the offset.
    func lineNumber(for offset: Int) -> Int {
        if lines.isEmpty {
            return 1
        }
        let clamped = max(0, min(offset, lines.last?.end ?? 0))
        var low = 0
        var high = lines.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].start <= clamped {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result + 1
    }

    /// Gets the line index (0-based) containing the given byte offset.
    ///
    /// - Parameter offset: The byte offset.
    /// - Returns: The index of the line containing the offset.
    func lineIndex(containing offset: Int) -> Int {
        if lines.isEmpty {
            return 0
        }
        let clamped = max(0, min(offset, (lines.last?.end ?? 0) - 1))
        var low = 0
        var high = lines.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].start <= clamped {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    /// Counts the number of lines between two byte offsets.
    ///
    /// - Parameters:
    ///   - startOffset: The starting byte offset.
    ///   - endOffset: The ending byte offset.
    /// - Returns: The number of lines in the range.
    func lineCount(from startOffset: Int, to endOffset: Int) -> Int {
        if endOffset <= startOffset {
            return 0
        }
        let startIndex = lineIndex(containing: startOffset)
        let endIndex = lineIndex(containing: endOffset - 1)
        return endIndex - startIndex + 1
    }
}

/// Represents an mbox "From " marker location.
internal struct MboxMarker {
    /// The byte offset where the marker starts.
    let start: Int
    /// The line index (0-based) of the marker.
    let lineIndex: Int
    /// The byte offset where the marker line content ends.
    let lineEnd: Int
    /// The length of the line break after the marker.
    let lineBreakLength: Int
}

/// A MIME message and entity reader.
///
/// `MimeReader` provides forward-only, read-only access to MIME data in a stream.
/// Unlike ``MimeParser``, which constructs complete ``MimeMessage`` and ``MimeEntity``
/// objects, `MimeReader` provides event-based callbacks as MIME structures are encountered,
/// allowing for more efficient processing of large messages.
///
/// ## Overview
///
/// To use `MimeReader`, subclass it and override the event methods to receive callbacks
/// as different parts of the MIME structure are encountered during parsing.
///
/// ## Example Usage
///
/// ```swift
/// class MyReader: MimeReader {
///     override func onMimeMessageBegin(_ beginOffset: Int, _ beginLineNumber: Int) {
///         print("Message starts at offset \(beginOffset)")
///     }
///
///     override func onMimePartEnd(_ contentType: ContentType, _ beginOffset: Int,
///                                  _ beginLineNumber: Int, _ headersEndOffset: Int,
///                                  _ endOffset: Int, _ lines: Int) {
///         print("Found part: \(contentType.mimeType)")
///     }
/// }
///
/// let reader = try MyReader(stream)
/// try reader.readMessage()
/// ```
open class MimeReader {
    /// The parser options used when reading MIME content.
    ///
    /// Gets or sets the parser options. These options control various aspects of parsing
    /// behavior such as RFC compliance modes and content length handling.
    public var options: ParserOptions

    /// The format of the input stream.
    ///
    /// Gets a value indicating whether the reader was initialized to parse a single entity
    /// (``MimeFormat/entity``) or an mbox stream containing multiple messages (``MimeFormat/mbox``).
    public private(set) var format: MimeFormat

    /// A value indicating whether the reader has reached the end of the input stream.
    ///
    /// When reading mbox-formatted streams, this property can be used to determine when
    /// all messages have been processed.
    public internal(set) var isEndOfStream: Bool = false

    /// The current position of the reader within the stream.
    ///
    /// Gets the current stream offset indicating how many bytes have been consumed.
    public var position: Int { currentOffset }

    private var data: [UInt8] = []
    private var lineMap = LineMap([])
    private var mboxMarkers: [MboxMarker] = []
    private var currentOffset: Int = 0
    private var currentMarkerIndex: Int = 0

    /// Provides access to the raw byte data being parsed (for internal use).
    internal var rawData: [UInt8] {
        data
    }

    /// Provides access to the current offset (for internal use).
    internal var internalOffset: Int {
        get { currentOffset }
        set { currentOffset = newValue }
    }

    /// Initializes a new instance of the `MimeReader` class.
    ///
    /// Creates a new `MimeReader` that will parse the specified stream using the default parser options.
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

    /// Initializes a new instance of the `MimeReader` class with custom parser options.
    ///
    /// Creates a new `MimeReader` that will parse the specified stream using the provided parser options.
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
    /// Resets the reader state and prepares to parse the specified stream.
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

    /// Reads the next message from the stream.
    ///
    /// Reads and processes the next MIME message from the stream, calling the appropriate
    /// event methods as different parts of the message structure are encountered.
    ///
    /// - Throws: An error if there was a problem reading the message.
    public func readMessage() throws {
        if isEndOfStream {
            return
        }
        switch format {
        case .entity:
            if currentOffset > 0 {
                isEndOfStream = true
                return
            }
            try parseMessageRange(start: 0, end: data.count, marker: nil)
            currentOffset = data.count
            isEndOfStream = true
        case .mbox:
            try parseNextMboxMessage()
        }
    }

    /// Asynchronously reads the next message from the stream.
    ///
    /// Reads and processes the next MIME message from the stream, calling the appropriate
    /// event methods as different parts of the message structure are encountered.
    ///
    /// - Throws: An error if there was a problem reading the message.
    public func readMessageAsync() async throws {
        try readMessage()
    }

    // MARK: - Events (override points)

    /// Called when an mbox marker is encountered in the stream.
    ///
    /// Override this method to receive notifications when an mbox "From " marker is found.
    /// This method is only called when parsing mbox-formatted streams.
    ///
    /// - Parameters:
    ///   - marker: The buffer containing the mbox marker bytes.
    ///   - startIndex: The index within the marker buffer where the marker begins.
    ///   - count: The length of the marker in bytes.
    ///   - beginOffset: The offset into the stream where the mbox marker begins.
    ///   - lineNumber: The line number where the mbox marker exists within the stream.
    open func onMboxMarkerRead(_ marker: [UInt8], startIndex: Int, count: Int, beginOffset: Int, lineNumber: Int) {
    }

    /// Called when the beginning of a message is encountered in the stream.
    ///
    /// Override this method to receive notifications when a new message begins.
    /// This method is always paired with a corresponding call to ``onMimeMessageEnd(_:_:_:_:_:)``.
    ///
    /// - Parameters:
    ///   - beginOffset: The offset into the stream where the message begins.
    ///   - beginLineNumber: The line number where the message begins.
    open func onMimeMessageBegin(_ beginOffset: Int, _ beginLineNumber: Int) {
    }

    /// Called when the end of a message is encountered in the stream.
    ///
    /// Override this method to receive notifications when a message ends.
    /// This method is always paired with a corresponding call to ``onMimeMessageBegin(_:_:)``.
    ///
    /// - Parameters:
    ///   - beginOffset: The offset into the stream where the message began.
    ///   - beginLineNumber: The line number where the message began.
    ///   - headersEndOffset: The offset where the message headers ended and content began.
    ///   - endOffset: The offset into the stream where the message ended.
    ///   - lines: The length of the message as measured in lines.
    open func onMimeMessageEnd(_ beginOffset: Int, _ beginLineNumber: Int, _ headersEndOffset: Int, _ endOffset: Int, _ lines: Int) {
    }

    /// Called when the beginning of a multipart entity is encountered in the stream.
    ///
    /// Override this method to receive notifications when a multipart entity begins.
    /// This method is always paired with a corresponding call to ``onMultipartEnd(_:_:_:_:_:_:)``.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the multipart entity.
    ///   - beginOffset: The offset into the stream where the entity begins.
    ///   - beginLineNumber: The line number where the entity begins.
    open func onMultipartBegin(_ contentType: ContentType, _ beginOffset: Int, _ beginLineNumber: Int) {
    }

    /// Called when the end of a multipart entity is encountered in the stream.
    ///
    /// Override this method to receive notifications when a multipart entity ends.
    /// This method is always paired with a corresponding call to ``onMultipartBegin(_:_:_:)``.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the multipart entity.
    ///   - beginOffset: The offset into the stream where the entity began.
    ///   - beginLineNumber: The line number where the entity began.
    ///   - headersEndOffset: The offset where the entity headers ended and content began.
    ///   - endOffset: The offset into the stream where the entity ended.
    ///   - lines: The length of the entity as measured in lines.
    open func onMultipartEnd(_ contentType: ContentType, _ beginOffset: Int, _ beginLineNumber: Int, _ headersEndOffset: Int, _ endOffset: Int, _ lines: Int) {
    }

    /// Called when the beginning of a message part entity is encountered in the stream.
    ///
    /// Override this method to receive notifications when a message part (e.g., message/rfc822) begins.
    /// This method is always paired with a corresponding call to ``onMessagePartEnd(_:_:_:_:_:_:)``.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the message part entity.
    ///   - beginOffset: The offset into the stream where the entity begins.
    ///   - beginLineNumber: The line number where the entity begins.
    open func onMessagePartBegin(_ contentType: ContentType, _ beginOffset: Int, _ beginLineNumber: Int) {
    }

    /// Called when the end of a message part entity is encountered in the stream.
    ///
    /// Override this method to receive notifications when a message part (e.g., message/rfc822) ends.
    /// This method is always paired with a corresponding call to ``onMessagePartBegin(_:_:_:)``.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the message part entity.
    ///   - beginOffset: The offset into the stream where the entity began.
    ///   - beginLineNumber: The line number where the entity began.
    ///   - headersEndOffset: The offset where the entity headers ended and content began.
    ///   - endOffset: The offset into the stream where the entity ended.
    ///   - lines: The length of the entity as measured in lines.
    open func onMessagePartEnd(_ contentType: ContentType, _ beginOffset: Int, _ beginLineNumber: Int, _ headersEndOffset: Int, _ endOffset: Int, _ lines: Int) {
    }

    /// Called when the beginning of a MIME part is encountered in the stream.
    ///
    /// Override this method to receive notifications when a MIME part (leaf node) begins.
    /// This method is always paired with a corresponding call to ``onMimePartEnd(_:_:_:_:_:_:)``.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the MIME part.
    ///   - beginOffset: The offset into the stream where the part begins.
    ///   - beginLineNumber: The line number where the part begins.
    open func onMimePartBegin(_ contentType: ContentType, _ beginOffset: Int, _ beginLineNumber: Int) {
    }

    /// Called when the end of a MIME part is encountered in the stream.
    ///
    /// Override this method to receive notifications when a MIME part (leaf node) ends.
    /// This method is always paired with a corresponding call to ``onMimePartBegin(_:_:_:)``.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the MIME part.
    ///   - beginOffset: The offset into the stream where the part began.
    ///   - beginLineNumber: The line number where the part began.
    ///   - headersEndOffset: The offset where the part headers ended and content began.
    ///   - endOffset: The offset into the stream where the part ended.
    ///   - lines: The length of the part as measured in lines.
    open func onMimePartEnd(_ contentType: ContentType, _ beginOffset: Int, _ beginLineNumber: Int, _ headersEndOffset: Int, _ endOffset: Int, _ lines: Int) {
    }
}

// MARK: - Parsing helpers

private extension MimeReader {
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

    func parseNextMboxMessage() throws {
        if currentOffset >= data.count {
            isEndOfStream = true
            return
        }

        var markerIndex = currentMarkerIndex
        while markerIndex < mboxMarkers.count && mboxMarkers[markerIndex].start < currentOffset {
            markerIndex += 1
        }
        if markerIndex >= mboxMarkers.count {
            if currentOffset == 0 {
                try parseMessageRange(start: 0, end: data.count, marker: nil)
                currentOffset = data.count
                isEndOfStream = true
            } else {
                isEndOfStream = true
            }
            return
        }

        let marker = mboxMarkers[markerIndex]
        let markerLineNumber = marker.lineIndex + 1
        let markerBytes = Array(data[marker.start..<marker.lineEnd])
        onMboxMarkerRead(markerBytes, startIndex: 0, count: markerBytes.count, beginOffset: marker.start, lineNumber: markerLineNumber)

        let messageStart = marker.lineEnd + marker.lineBreakLength
        let messageLineNumber = lineMap.lineNumber(for: messageStart)

        var messageEnd = data.count
        var nextMarkerIndex = markerIndex + 1

        if options.respectContentLength, let contentLength = parseContentLength(startOffset: messageStart) {
            let headerEndIndex = headerBodySeparatorOffset(in: data, startOffset: messageStart) ?? messageStart
            let bodyStart = headerEndIndex
            let contentEnd = min(bodyStart + contentLength, data.count)
            while nextMarkerIndex < mboxMarkers.count && mboxMarkers[nextMarkerIndex].start < contentEnd {
                nextMarkerIndex += 1
            }
            if nextMarkerIndex < mboxMarkers.count {
                let nextMarker = mboxMarkers[nextMarkerIndex]
                messageEnd = adjustedEndOffset(beforeLineIndex: nextMarker.lineIndex)
            } else {
                messageEnd = data.count
            }
        } else if nextMarkerIndex < mboxMarkers.count {
            let nextMarker = mboxMarkers[nextMarkerIndex]
            messageEnd = adjustedEndOffset(beforeLineIndex: nextMarker.lineIndex)
        }

        if messageStart <= messageEnd {
            try parseMessageRange(start: messageStart, end: messageEnd, marker: (marker.start, messageLineNumber))
        }

        currentOffset = messageEnd
        currentMarkerIndex = nextMarkerIndex

        if currentOffset >= data.count {
            isEndOfStream = true
        }
    }

    func parseMessageRange(start: Int, end: Int, marker: (offset: Int, lineNumber: Int)?) throws {
        let beginLineNumber = lineMap.lineNumber(for: start)
        onMimeMessageBegin(start, beginLineNumber)

        let messageBytes = data[start..<end]
        let (headers, bodyBytes) = MimeMessage.parseHeaders(messageBytes)
        let headerEndOffset = start + (messageBytes.count - bodyBytes.count)
        let messageEndOffset = end

        if let contentType = resolveContentType(headers: headers, parent: nil) {
            let bodyStartOffset = headerEndOffset
            let bodyLineNumber = lineMap.lineNumber(for: bodyStartOffset)
            try parseEntity(
                contentType: contentType,
                parentContentType: nil,
                headers: headers,
                bodyBytes: bodyBytes,
                baseOffset: start,
                bodyStartOffset: bodyStartOffset,
                bodyEndOffset: messageEndOffset,
                bodyLineNumber: bodyLineNumber,
                depth: 0
            )
        }

        let lines = lineMap.lineCount(from: headerEndOffset, to: messageEndOffset)
        onMimeMessageEnd(start, beginLineNumber, headerEndOffset, messageEndOffset, lines)
    }

    func parseEntity(
        contentType: ContentType,
        parentContentType: ContentType?,
        headers: HeaderList,
        bodyBytes: ArraySlice<UInt8>,
        baseOffset: Int,
        bodyStartOffset: Int,
        bodyEndOffset: Int,
        bodyLineNumber: Int,
        depth: Int
    ) throws {
        let beginOffset = baseOffset
        let beginLineNumber = lineMap.lineNumber(for: beginOffset)
        let headerEndOffset = bodyStartOffset
        let lines = lineMap.lineCount(from: headerEndOffset, to: bodyEndOffset)

        let encoding = parseContentEncoding(headers: headers)

        if depth >= options.maxMimeDepth {
            onMimePartBegin(contentType, beginOffset, beginLineNumber)
            onMimePartEnd(contentType, beginOffset, beginLineNumber, headerEndOffset, bodyEndOffset, lines)
            return
        }

        if isMultipart(contentType), let boundary = contentType.boundary {
            onMultipartBegin(contentType, beginOffset, beginLineNumber)
            try parseMultipart(boundary: boundary, parentContentType: contentType, bodyStartOffset: bodyStartOffset, bodyEndOffset: bodyEndOffset, depth: depth + 1)
            onMultipartEnd(contentType, beginOffset, beginLineNumber, headerEndOffset, bodyEndOffset, lines)
            return
        }

        if isMessagePart(contentType, encoding: encoding) {
            onMessagePartBegin(contentType, beginOffset, beginLineNumber)
            try parseNestedMessage(bodyStartOffset: bodyStartOffset, bodyEndOffset: bodyEndOffset, depth: depth + 1)
            onMessagePartEnd(contentType, beginOffset, beginLineNumber, headerEndOffset, bodyEndOffset, lines)
            return
        }

        onMimePartBegin(contentType, beginOffset, beginLineNumber)
        onMimePartEnd(contentType, beginOffset, beginLineNumber, headerEndOffset, bodyEndOffset, lines)
    }

    func parseNestedMessage(bodyStartOffset: Int, bodyEndOffset: Int, depth: Int) throws {
        let beginLineNumber = lineMap.lineNumber(for: bodyStartOffset)
        onMimeMessageBegin(bodyStartOffset, beginLineNumber)
        let bytes = data[bodyStartOffset..<bodyEndOffset]
        let (headers, bodyBytes) = MimeMessage.parseHeaders(bytes)
        let headerEndOffset = bodyStartOffset + (bytes.count - bodyBytes.count)
        if let contentType = resolveContentType(headers: headers, parent: nil) {
            let bodyLineNumber = lineMap.lineNumber(for: headerEndOffset)
            try parseEntity(
                contentType: contentType,
                parentContentType: nil,
                headers: headers,
                bodyBytes: bodyBytes,
                baseOffset: bodyStartOffset,
                bodyStartOffset: headerEndOffset,
                bodyEndOffset: bodyEndOffset,
                bodyLineNumber: bodyLineNumber,
                depth: depth
            )
        }
        let lines = lineMap.lineCount(from: headerEndOffset, to: bodyEndOffset)
        onMimeMessageEnd(bodyStartOffset, beginLineNumber, headerEndOffset, bodyEndOffset, lines)
    }

    func parseMultipart(boundary: String, parentContentType: ContentType, bodyStartOffset: Int, bodyEndOffset: Int, depth: Int) throws {
        let boundaryBytes = Array(("--" + boundary).utf8)
        var currentPartStart: Int? = nil

        let startLineIndex = lineMap.lineIndex(containing: bodyStartOffset)
        var lineIndex = startLineIndex
        while lineIndex < lineMap.lines.count {
            let line = lineMap.lines[lineIndex]
            if line.start >= bodyEndOffset {
                break
            }
            let lineSlice = data[line.start..<min(line.end, bodyEndOffset)]
            if isBoundaryLine(lineSlice, boundary: boundaryBytes) {
                if let start = currentPartStart {
                    let partEnd = adjustedEndOffset(beforeLineIndex: lineIndex)
                    try parseChildPart(startOffset: start, endOffset: partEnd, parentContentType: parentContentType, depth: depth)
                }
                if isEndBoundaryLine(lineSlice, boundary: boundaryBytes) {
                    currentPartStart = nil
                    break
                }
                currentPartStart = line.end + line.breakLength
            }
            lineIndex += 1
        }

        if let start = currentPartStart, start <= bodyEndOffset {
            try parseChildPart(startOffset: start, endOffset: bodyEndOffset, parentContentType: parentContentType, depth: depth)
        }
    }

    func parseChildPart(startOffset: Int, endOffset: Int, parentContentType: ContentType, depth: Int) throws {
        if startOffset > endOffset {
            return
        }
        let bytes = data[startOffset..<endOffset]
        let headers: HeaderList
        let bodyBytes: ArraySlice<UInt8>
        let headerEndOffset: Int
        if bytes.count == 1, bytes[startOffset] == 0x0A || bytes[startOffset] == 0x0D {
            headers = HeaderList()
            bodyBytes = []
            headerEndOffset = startOffset + 1
        } else {
            let parsed = MimeMessage.parseHeaders(bytes)
            headers = parsed.0
            bodyBytes = parsed.1
            headerEndOffset = startOffset + (bytes.count - bodyBytes.count)
        }
        let bodyLineNumber = lineMap.lineNumber(for: headerEndOffset)
        if let contentType = resolveContentType(headers: headers, parent: parentContentType) {
            try parseEntity(
                contentType: contentType,
                parentContentType: parentContentType,
                headers: headers,
                bodyBytes: bodyBytes,
                baseOffset: startOffset,
                bodyStartOffset: headerEndOffset,
                bodyEndOffset: endOffset,
                bodyLineNumber: bodyLineNumber,
                depth: depth
            )
        }
    }

    func resolveContentType(headers: HeaderList, parent: ContentType?) -> ContentType? {
        if let value = headers[.contentType] ?? headers.first(where: { $0.field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content-type" })?.value {
            if let parsed = try? ContentType(parsing: value) {
                return parsed
            }
            return try? ContentType("application", "octet-stream")
        }
        if let parent, parent.isMimeType("multipart", "digest") {
            return try? ContentType("message", "rfc822")
        }
        return try? ContentType("text", "plain")
    }

    func parseContentEncoding(headers: HeaderList) -> ContentEncoding {
        guard let value = headers[.contentTransferEncoding] else {
            return .default
        }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "7bit":
            return .sevenBit
        case "8bit":
            return .eightBit
        case "binary":
            return .binary
        case "base64":
            return .base64
        case "quoted-printable":
            return .quotedPrintable
        case "x-uuencode", "uuencode":
            return .uuEncode
        default:
            return .default
        }
    }

    func isMultipart(_ contentType: ContentType) -> Bool {
        contentType.mediaType.caseInsensitiveCompare("multipart") == .orderedSame
    }

    func isMessagePart(_ contentType: ContentType, encoding: ContentEncoding) -> Bool {
        if encoding == .base64 || encoding == .quotedPrintable || encoding == .uuEncode {
            return false
        }
        if contentType.mediaType.caseInsensitiveCompare("message") == .orderedSame {
            let subtype = contentType.mediaSubtype.lowercased()
            switch subtype {
            case "rfc822", "news", "global", "global-headers", "external-body", "rfc2822":
                return true
            default:
                return false
            }
        }
        return contentType.isMimeType("text", "rfc822-headers")
    }

    func isBoundaryLine(_ line: ArraySlice<UInt8>, boundary: [UInt8]) -> Bool {
        if line.count < boundary.count {
            return false
        }
        if !line.starts(with: boundary) {
            return false
        }
        let remainder = line.dropFirst(boundary.count)
        return remainder.allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x2D }
    }

    func isEndBoundaryLine(_ line: ArraySlice<UInt8>, boundary: [UInt8]) -> Bool {
        if line.count < boundary.count + 2 {
            return false
        }
        if !line.starts(with: boundary) {
            return false
        }
        let remainder = line.dropFirst(boundary.count)
        if remainder.count < 2 {
            return false
        }
        if remainder[remainder.startIndex] != 0x2D || remainder[remainder.index(after: remainder.startIndex)] != 0x2D {
            return false
        }
        return true
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
        let bytes = Array(data[startOffset..<data.count])
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
