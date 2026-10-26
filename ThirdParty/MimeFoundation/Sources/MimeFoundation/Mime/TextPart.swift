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
// TextPart.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with text parts.
public enum TextPartError: Error, Equatable, Sendable {
    /// The specified charset is not supported.
    case unsupportedCharset

    /// An encoding was specified more than once.
    case duplicateEncoding

    /// Text was specified more than once.
    case duplicateText

    /// An invalid argument was provided.
    case invalidArgument
}

/// A MIME part containing text content.
///
/// A ``TextPart`` represents a text-based MIME part such as text/plain, text/html,
/// or text/enriched. The text content can be accessed and modified through the
/// ``text`` property, and the encoding is automatically handled.
///
/// ## Topics
///
/// ### Creating Text Parts
/// - ``init(_:)``
/// - ``init(_:_:)``
/// - ``init(_:args:)``
/// - ``init(_:)``
///
/// ### Text Content
/// - ``text``
/// - ``getText(_:)-6yx98``
/// - ``getText(_:)-8rh9e``
/// - ``setText(_:_:)-4ys6z``
/// - ``setText(_:_:)-5xk5f``
///
/// ### Text Format Properties
/// - ``format``
/// - ``isHtml``
/// - ``isPlain``
/// - ``isFlowed``
/// - ``isEnriched``
/// - ``isRichText``
/// - ``isFormat(_:)``
///
/// ### Encoding Detection
/// - ``tryDetectEncoding(_:confidence:)``
open class TextPart: MimePart {
    private static var rtfContentType: ContentType {
        guard let ct = try? ContentType("text", "rtf") else {
            preconditionFailure("Invalid static content type - this is a programming error")
        }
        return ct
    }

    private var textStorage: String?
    private var textLoaded = false

    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    /// The text content of the part.
    ///
    /// Gets or sets the text content using automatic encoding detection for reading
    /// and UTF-8 encoding for writing. When reading, the encoding is detected from
    /// the Content-Type charset parameter, BOM (byte order mark), or HTML meta tags.
    public var text: String? {
        get {
            if textLoaded {
                return textStorage
            }
            var encoding: String.Encoding? = nil
            let value = getText(&encoding)
            textStorage = value
            textLoaded = true
            return value
        }
        set {
            textLoaded = true
            if let value = newValue {
                setText(.utf8, value)
            } else {
                textStorage = nil
                content = nil
            }
        }
    }

    /// Initializes a new text part with the specified subtype.
    ///
    /// Creates a new text part with the media type "text" and the specified subtype.
    ///
    /// - Parameter subtype: The media subtype (e.g., "plain", "html", "enriched").
    public convenience init(_ subtype: String) {
        guard let contentType = try? ContentType("text", subtype) else {
            preconditionFailure("Invalid subtype '\(subtype)' for text content type")
        }
        self.init(contentType)
    }

    public convenience init(_ subtype: String, _ args: Any?...) throws {
        try self.init(subtype, args: args)
    }

    @available(*, unavailable, message: "Use TextPart(subtype:args:) or TextPart(format:) for text parts.")
    public convenience init(_ mediaType: String, _ mediaSubtype: String, _ args: Any...) throws {
        fatalError("Use TextPart(subtype:args:) instead.")
    }

    /// Initializes a new text part with the specified subtype and text content.
    ///
    /// Creates a new text part with the specified subtype and sets the text content
    /// using UTF-8 encoding.
    ///
    /// - Parameters:
    ///   - subtype: The media subtype (e.g., "plain", "html", "enriched").
    ///   - text: The text content.
    public convenience init(_ subtype: String, _ text: String) {
        self.init(subtype)
        setText(.utf8, text)
    }

    public convenience init(_ subtype: String, args: [Any?]) throws {
        self.init(subtype)
        try applyArgs(args)
    }

    /// Initializes a new text part with the specified text format.
    ///
    /// Creates a new text part configured for the specified format. For example,
    /// ``TextFormat/plain`` creates a text/plain part, and ``TextFormat/html`` creates
    /// a text/html part.
    ///
    /// - Parameter format: The text format.
    public convenience init(_ format: TextFormat) {
        switch format {
        case .plain:
            self.init("plain")
        case .flowed:
            self.init("plain")
            contentType.format = "flowed"
        case .html:
            self.init("html")
        case .enriched:
            self.init("enriched")
        case .richText, .compressedRichText:
            self.init(Self.rtfContentType)
        }
    }

    public convenience init() {
        self.init("plain")
    }

    private func applyArgs(_ args: [Any?]) throws {
        var encoding: String.Encoding?
        var text: String?

        for obj in args {
            guard let obj else { continue }
            if tryInit(obj) {
                continue
            }
            if let enc = obj as? String.Encoding {
                if encoding != nil {
                    throw TextPartError.duplicateEncoding
                }
                encoding = enc
                continue
            }
            if let value = obj as? String {
                if text != nil {
                    throw TextPartError.duplicateText
                }
                text = value
                continue
            }
            throw TextPartError.invalidArgument
        }

        if let text {
            setText(encoding ?? .utf8, text)
        }
    }

    /// The text format of the content.
    ///
    /// Returns the text format based on the Content-Type of the part.
    public var format: TextFormat {
        if isMimeType("text", "plain") {
            if let format = contentType.format?.trimmingCharacters(in: .whitespacesAndNewlines),
               format.caseInsensitiveCompare("flowed") == .orderedSame {
                return .flowed
            }
            return .plain
        }
        if isMimeType("text", "html") {
            return .html
        }
        if isMimeType("text", "rtf") {
            return .richText
        }
        if isMimeType("text", "enriched") || isMimeType("text", "richtext") {
            return .enriched
        }
        if isMimeType("application", "rtf") {
            return .richText
        }
        return .plain
    }

    /// Whether this text part is HTML.
    ///
    /// Returns `true` if the Content-Type is text/html; otherwise, `false`.
    public var isHtml: Bool {
        isMimeType("text", "html")
    }

    /// Whether this text part is plain text.
    ///
    /// Returns `true` if the Content-Type is text/plain; otherwise, `false`.
    public var isPlain: Bool {
        isMimeType("text", "plain")
    }

    /// Whether this text part is flowed plain text.
    ///
    /// Returns `true` if the Content-Type is text/plain with format=flowed; otherwise, `false`.
    public var isFlowed: Bool {
        guard isPlain,
              let format = contentType.format?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return format.caseInsensitiveCompare("flowed") == .orderedSame
    }

    /// Whether this text part is enriched text.
    ///
    /// Returns `true` if the Content-Type is text/enriched or text/richtext; otherwise, `false`.
    public var isEnriched: Bool {
        isMimeType("text", "enriched") || isMimeType("text", "richtext")
    }

    /// Whether this text part is RTF (Rich Text Format).
    ///
    /// Returns `true` if the Content-Type is text/rtf or application/rtf; otherwise, `false`.
    public var isRichText: Bool {
        isMimeType("text", "rtf") || isMimeType("application", "rtf")
    }

    /// Checks whether this text part is in the specified format.
    ///
    /// - Parameter format: The text format to check.
    /// - Returns: `true` if this part is in the specified format; otherwise, `false`.
    public func isFormat(_ format: TextFormat) -> Bool {
        switch format {
        case .plain:
            return isPlain
        case .flowed:
            return isFlowed
        case .html:
            return isHtml
        case .enriched:
            return isEnriched
        case .richText:
            return isRichText
        case .compressedRichText:
            return false
        }
    }

    public func tryDetectEncoding(
        _ encoding: inout String.Encoding?,
        confidence: inout TextEncodingConfidence
    ) -> Bool {
        if content == nil {
            confidence = .irrelevant
            encoding = .ascii
            return true
        }

        if let charsetEncoding = contentType.charsetEncoding {
            confidence = .certain
            encoding = charsetEncoding
            return true
        }

        if let content, let bomEncoding = tryDetectBomEncoding(content) {
            confidence = .certain
            encoding = bomEncoding
            return true
        }

        if isHtml, let content {
            return TextPart.tryDetectHtmlEncoding(content, encoding: &encoding, confidence: &confidence)
        }

        confidence = .undefined
        encoding = nil
        return false
    }

    public func getText(_ encoding: inout String.Encoding?) -> String {
        var detectedConfidence: TextEncodingConfidence = .undefined
        if !tryDetectEncoding(&encoding, confidence: &detectedConfidence) {
            encoding = .utf8
        }
        if let encoding, let decoded = try? decodeText(using: encoding) {
            return TextPart.normalizeNewLines(decoded, newLine: FormatOptions.default.newLine)
        }
        encoding = .isoLatin1
        if let decoded = try? decodeText(using: .isoLatin1) {
            return TextPart.normalizeNewLines(decoded, newLine: FormatOptions.default.newLine)
        }
        return ""
    }

    /// Sets the text content using the specified charset name.
    ///
    /// - Parameters:
    ///   - charset: The MIME charset name (e.g., "utf-8", "iso-8859-1").
    ///   - text: The text content to set.
    /// - Throws: `TextPartError.unsupportedCharset` if the charset is not recognized.
    public func setText(_ charset: String, _ text: String) throws {
        guard let encoding = CharsetUtils.getEncoding(charset) else {
            throw TextPartError.unsupportedCharset
        }
        setText(encoding, text)
        contentType.charset = CharsetUtils.getMimeCharset(encoding)
    }

    /// Sets the text content using the specified encoding.
    ///
    /// - Parameters:
    ///   - encoding: The string encoding to use for converting the text to bytes.
    ///   - text: The text content to set.
    public func setText(_ encoding: String.Encoding, _ text: String) {
        let normalized = TextPart.normalizeNewLines(text, newLine: "\r\n")
        let bytes = CharsetUtils.getBytes(normalized, encoding: encoding)
        content = MimeContent(MemoryStream(bytes, writable: false))
        textStorage = text
        textLoaded = true
        contentType.charset = CharsetUtils.getMimeCharset(encoding)
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    public override func writeTo(_ options: FormatOptions, _ stream: MimeStream) throws {
        try super.writeTo(options, stream)
    }

    public func getText(_ charset: String) throws -> String {
        guard let encoding = CharsetUtils.getEncoding(charset) else {
            throw TextPartError.unsupportedCharset
        }
        return try getText(encoding)
    }

    public func getText(_ encoding: String.Encoding) throws -> String {
        guard let content else {
            return ""
        }
        let data = readDecodedBytes(from: content)
        if let decoded = String(data: Data(data), encoding: encoding) {
            return TextPart.normalizeNewLines(decoded, newLine: FormatOptions.default.newLine)
        }
        return ""
    }

    private func decodeText(using encoding: String.Encoding) throws -> String? {
        guard let content else {
            return ""
        }
        let data = readDecodedBytes(from: content)
        return String(data: Data(data), encoding: encoding)
    }

    private func isMimeType(_ mediaType: String, _ mediaSubtype: String) -> Bool {
        contentType.isMimeType(mediaType, mediaSubtype)
    }

    private enum HtmlTagState {
        case none
        case html
        case head
        case stop
    }

    private struct HtmlTag {
        let name: String
        let isEndTag: Bool
        let isEmptyElement: Bool
        let attributes: [(String, String?)]
    }

    private static func tryDetectHtmlEncoding(
        _ content: MimeContent,
        encoding: inout String.Encoding?,
        confidence: inout TextEncodingConfidence
    ) -> Bool {
        guard let bytes = try? readPrefix(content, length: 1024) else {
            confidence = .undefined
            encoding = nil
            return false
        }
        guard let text = String(data: Data(bytes), encoding: .isoLatin1) else {
            confidence = .undefined
            encoding = nil
            return false
        }

        var state: HtmlTagState = .none
        var index = text.startIndex

        while let open = text[index...].firstIndex(of: "<") {
            guard let close = text[open...].firstIndex(of: ">") else {
                break
            }

            let tagText = String(text[text.index(after: open)..<close])
            index = text.index(after: close)

            guard let tag = parseHtmlTag(tagText) else {
                continue
            }

            switch tag.name {
            case "html":
                if state == .none {
                    if tag.isEndTag || tag.isEmptyElement {
                        state = .stop
                    } else {
                        state = .html
                    }
                }
            case "head":
                if state == .html {
                    if tag.isEndTag || tag.isEmptyElement {
                        state = .stop
                    } else {
                        state = .head
                    }
                }
            case "meta":
                if state == .head && !tag.isEndTag {
                    if let detected = detectMetaCharset(tag.attributes) {
                        encoding = detected
                        if encoding == .utf16 || encoding == .utf16BigEndian || encoding == .utf16LittleEndian {
                            encoding = .utf8
                        }
                        confidence = .tentative
                        return true
                    }
                }
            case "body":
                state = .stop
            default:
                break
            }

            if state == .stop {
                break
            }
        }

        confidence = .undefined
        encoding = nil
        return false
    }

    private static func detectMetaCharset(_ attributes: [(String, String?)]) -> String.Encoding? {
        var seen = Set<String>()
        var gotPragma = false
        var needPragma: Bool? = nil
        var charset: String? = nil

        for (name, value) in attributes {
            let key = name.lowercased()
            if !seen.insert(key).inserted {
                continue
            }
            guard let value else {
                continue
            }
            switch key {
            case "http-equiv":
                if value.caseInsensitiveCompare("Content-Type") == .orderedSame {
                    gotPragma = true
                }
            case "content":
                if charset == nil {
                    if let parsed = try? ContentType(parsing: value),
                       let param = parsed.charset,
                       !param.isEmpty {
                        charset = param.trimmingCharacters(in: .whitespacesAndNewlines)
                        needPragma = true
                    }
                }
            case "charset":
                if !value.isEmpty {
                    charset = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    needPragma = false
                }
            default:
                break
            }
        }

        guard let charset, let needPragma else {
            return nil
        }

        if needPragma && !gotPragma {
            return nil
        }

        var effective = charset
        if charset.caseInsensitiveCompare("x-user-defined") == .orderedSame {
            effective = "windows-1252"
        }

        return CharsetUtils.getEncoding(effective)
    }

    private static func parseHtmlTag(_ text: String) -> HtmlTag? {
        var tagText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if tagText.isEmpty {
            return nil
        }

        var isEndTag = false
        if tagText.first == "/" {
            isEndTag = true
            tagText.removeFirst()
            tagText = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var isEmptyElement = false
        if tagText.hasSuffix("/") {
            isEmptyElement = true
            tagText.removeLast()
            tagText = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let nameEnd = tagText.firstIndex(where: { $0.isWhitespace }) ?? tagText.endIndex
        let name = String(tagText[..<nameEnd]).lowercased()
        let rest = nameEnd < tagText.endIndex ? String(tagText[tagText.index(after: nameEnd)...]) : ""
        let attributes = parseHtmlAttributes(rest)

        if name.isEmpty {
            return nil
        }

        return HtmlTag(name: name, isEndTag: isEndTag, isEmptyElement: isEmptyElement, attributes: attributes)
    }

    private static func parseHtmlAttributes(_ text: String) -> [(String, String?)] {
        var attributes: [(String, String?)] = []
        var index = text.startIndex

        func skipWhitespace() {
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }
        }

        func isNameChar(_ ch: Character) -> Bool {
            guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else {
                return false
            }
            let value = scalar.value
            return (value >= 0x41 && value <= 0x5A)
                || (value >= 0x61 && value <= 0x7A)
                || (value >= 0x30 && value <= 0x39)
                || value == 0x2D
                || value == 0x5F
                || value == 0x3A
        }

        while index < text.endIndex {
            skipWhitespace()
            if index >= text.endIndex {
                break
            }

            let nameStart = index
            while index < text.endIndex, isNameChar(text[index]) {
                index = text.index(after: index)
            }

            if index == nameStart {
                break
            }

            let name = String(text[nameStart..<index])
            skipWhitespace()

            var value: String? = nil
            if index < text.endIndex, text[index] == "=" {
                index = text.index(after: index)
                skipWhitespace()
                if index < text.endIndex {
                    if text[index] == "\"" || text[index] == "'" {
                        let quote = text[index]
                        index = text.index(after: index)
                        let valueStart = index
                        while index < text.endIndex, text[index] != quote {
                            index = text.index(after: index)
                        }
                        value = String(text[valueStart..<index])
                        if index < text.endIndex {
                            index = text.index(after: index)
                        }
                    } else {
                        let valueStart = index
                        while index < text.endIndex, !text[index].isWhitespace {
                            index = text.index(after: index)
                        }
                        value = String(text[valueStart..<index])
                    }
                } else {
                    value = ""
                }
            }

            attributes.append((name.lowercased(), value))
        }

        return attributes
    }

    private func tryDetectBomEncoding(_ content: MimeContent) -> String.Encoding? {
        let bytes = readDecodedBytes(from: content)
        guard !bytes.isEmpty else { return nil }
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            return .utf8
        }
        if bytes.count >= 2, bytes[0] == 0xFE, bytes[1] == 0xFF {
            return .utf16BigEndian
        }
        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] == 0xFE {
            return .utf16LittleEndian
        }
        return nil
    }

    private func readDecodedBytes(from content: MimeContent) -> [UInt8] {
        let memory = MemoryStream()
        _ = try? content.decodeTo(memory)
        return memory.toByteArray()
    }

    private static func readPrefix(_ content: MimeContent, length: Int) throws -> [UInt8] {
        let memory = MemoryStream()
        try content.decodeTo(memory)
        let bytes = memory.toByteArray()
        if bytes.count <= length {
            return bytes
        }
        return Array(bytes.prefix(length))
    }

    private static func normalizeNewLines(_ text: String, newLine: String) -> String {
        var result = ""
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\r" {
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 1
                }
                result.append(contentsOf: newLine)
            } else if scalar == "\n" {
                result.append(contentsOf: newLine)
            } else {
                result.unicodeScalars.append(scalar)
            }
            index += 1
        }
        return result
    }
}
