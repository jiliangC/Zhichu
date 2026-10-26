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
// Header.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with MIME headers.
public enum HeaderError: Error, Equatable, Sendable {
    /// The header identifier is unknown or invalid.
    case unknownHeaderId
    /// The field name is empty.
    case emptyFieldName
    /// The field name contains illegal characters.
    case invalidFieldName
    /// The raw value is invalid (e.g., does not end with a newline).
    case invalidRawValue
    /// The specified charset is not supported.
    case unsupportedCharset
}

/// A class representing a Message or MIME header.
///
/// Represents a single header field and value pair, such as `Subject: Hello World`
/// or `Content-Type: text/plain; charset=utf-8`.
///
/// ## Overview
///
/// Headers in email messages follow the format defined in RFC 5322, with a field name
/// followed by a colon, followed by the field value. Header values may be encoded
/// according to RFC 2047 for non-ASCII characters.
///
/// ## Example
///
/// ```swift
/// let header = Header(.subject, value: "Hello World")
/// print(header.field)  // "Subject"
/// print(header.value)  // "Hello World"
/// ```
public final class Header: CustomStringConvertible, Equatable, Comparable, Hashable {
    /// The header identifier.
    ///
    /// This property provides an enumerated identifier for the header, which is useful
    /// for switch statements and performance-sensitive code. For custom headers that
    /// are not part of the ``HeaderId`` enumeration, this will be ``HeaderId/unknown``.
    public let id: HeaderId

    /// The name of the header field.
    ///
    /// This is the string representation of the header name, such as "Subject",
    /// "Content-Type", or "X-Custom-Header".
    public let field: String

    /// The raw field name of the header as bytes.
    ///
    /// Contains the raw field name of the header as ASCII bytes.
    public let rawField: [UInt8]

    /// Indicates whether the header is invalid.
    ///
    /// A header is considered invalid if it could not be properly parsed according
    /// to RFC 5322 standards. Invalid headers are preserved but may not be
    /// processed correctly.
    public internal(set) var isInvalid: Bool

    private var encodingStorage: String.Encoding

    /// The character encoding used for encoding the header value.
    ///
    /// When setting a new value, the header will be re-encoded using this encoding
    /// according to the rules of RFC 2047.
    public var encoding: String.Encoding {
        get { encodingStorage }
        set {
            guard encodingStorage != newValue else { return }
            encodingStorage = newValue
            onChanged()
        }
    }

    internal let options: ParserOptions
    private var rawValueStorage: [UInt8]
    private var textValue: String?
    private var explicitRawValue: Bool

    /// The decoded header value.
    ///
    /// Gets or sets the decoded header value, suitable for displaying to the user.
    /// When getting, the value is decoded from the raw bytes using RFC 2047 decoding
    /// and unfolded to remove line breaks.
    ///
    /// When setting, the value is encoded using UTF-8 by default. To use a different
    /// encoding, use ``setValue(_:encoding:value:)`` instead.
    public var value: String {
        get {
            if let textValue {
                return textValue
            }
            let decoded = Header.unfold(Rfc2047.decodeText(options, rawValueStorage, startIndex: 0, count: rawValueStorage.count))
            textValue = decoded
            return decoded
        }
        set {
            setValue(.default, encoding: encoding, value: newValue)
        }
    }

    /// The raw value of the header as bytes.
    ///
    /// Contains the raw value of the header before any decoding or charset conversion.
    /// This is the value as it appears in the message source.
    public var rawValue: [UInt8] {
        rawValueStorage
    }

    internal var changed: ((Header) -> Void)?

    /// Creates a new header with the specified identifier and value.
    ///
    /// Creates a new message or entity header for the specified field and value pair
    /// with the UTF-8 encoding.
    ///
    /// - Parameters:
    ///   - id: The header identifier. Must not be ``HeaderId/unknown``.
    ///   - value: The header value.
    ///   - encoding: The character encoding to use for encoding the value according
    ///               to RFC 2047. Defaults to UTF-8.
    ///
    /// - Precondition: `id` must not be ``HeaderId/unknown``.
    public init(_ id: HeaderId, value: String, encoding: String.Encoding = .utf8) {
        precondition(id != .unknown, "HeaderId.unknown is not valid for Header initialization.")
        self.options = .default
        self.id = id
        self.field = id.headerName
        self.encodingStorage = encoding
        self.rawField = Array(field.utf8)
        self.isInvalid = false
        self.rawValueStorage = []
        self.textValue = nil
        self.explicitRawValue = false
        setValue(.default, encoding: encoding, value: value)
    }

    /// Creates a new header with the specified field name and value.
    ///
    /// Creates a new message or entity header for the specified field and value pair
    /// with the UTF-8 encoding.
    ///
    /// - Parameters:
    ///   - field: The name of the header field. Must contain only ASCII characters
    ///            that are valid in header field names.
    ///   - value: The header value.
    ///   - encoding: The character encoding to use for encoding the value according
    ///               to RFC 2047. Defaults to UTF-8.
    ///
    /// - Precondition: `field` must not be empty and must contain only valid
    ///                 ASCII field-text characters (printable ASCII except colon).
    public init(field: String, value: String, encoding: String.Encoding = .utf8) {
        let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!trimmed.isEmpty, "Header field names must not be empty.")
        precondition(Header.isValidFieldName(trimmed), "Header field names must contain only ASCII field-text characters.")
        self.options = .default
        self.field = trimmed
        self.id = HeaderId.from(field: trimmed)
        self.encodingStorage = encoding
        self.rawField = Array(trimmed.utf8)
        self.isInvalid = false
        self.rawValueStorage = []
        self.textValue = nil
        self.explicitRawValue = false
        setValue(.default, encoding: encoding, value: value)
    }

    /// Creates a new header with the specified identifier and value, with validation.
    ///
    /// Creates a new message or entity header for the specified field and value pair.
    /// Unlike ``init(_:value:encoding:)``, this initializer throws an error instead
    /// of using a precondition for invalid inputs.
    ///
    /// - Parameters:
    ///   - id: The header identifier.
    ///   - value: The header value.
    ///   - encoding: The character encoding to use. Defaults to UTF-8.
    ///
    /// - Throws: ``HeaderError/unknownHeaderId`` if `id` is ``HeaderId/unknown``.
    public init(validating id: HeaderId, value: String, encoding: String.Encoding = .utf8) throws {
        guard id != .unknown else {
            throw HeaderError.unknownHeaderId
        }
        self.options = .default
        self.id = id
        self.field = id.headerName
        self.encodingStorage = encoding
        self.rawField = Array(field.utf8)
        self.isInvalid = false
        self.rawValueStorage = []
        self.textValue = nil
        self.explicitRawValue = false
        setValue(.default, encoding: encoding, value: value)
    }

    /// Creates a new header with the specified field name and value, with validation.
    ///
    /// Creates a new message or entity header for the specified field and value pair.
    /// Unlike ``init(field:value:encoding:)``, this initializer throws an error instead
    /// of using a precondition for invalid inputs.
    ///
    /// - Parameters:
    ///   - field: The name of the header field.
    ///   - value: The header value.
    ///   - encoding: The character encoding to use. Defaults to UTF-8.
    ///
    /// - Throws: ``HeaderError/emptyFieldName`` if the field name is empty.
    /// - Throws: ``HeaderError/invalidFieldName`` if the field name contains
    ///           illegal characters.
    public init(validating field: String, value: String, encoding: String.Encoding = .utf8) throws {
        let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HeaderError.emptyFieldName
        }
        guard Header.isValidFieldName(trimmed) else {
            throw HeaderError.invalidFieldName
        }
        self.options = .default
        self.field = trimmed
        self.id = HeaderId.from(field: trimmed)
        self.encodingStorage = encoding
        self.rawField = Array(trimmed.utf8)
        self.isInvalid = false
        self.rawValueStorage = []
        self.textValue = nil
        self.explicitRawValue = false
        setValue(.default, encoding: encoding, value: value)
    }

    internal init(_ options: ParserOptions, _ id: HeaderId, _ field: String, _ rawValue: [UInt8]) {
        self.options = options
        self.id = id
        self.field = field
        self.rawField = Array(field.utf8)
        self.encodingStorage = .utf8
        self.isInvalid = false
        self.rawValueStorage = rawValue
        self.textValue = nil
        self.explicitRawValue = false
    }

    internal init(_ options: ParserOptions, fieldBytes: [UInt8], fieldNameLength: Int, rawValue: [UInt8]) {
        let nameBytes = Array(fieldBytes.prefix(fieldNameLength))
        self.options = options
        self.field = String(bytes: nameBytes, encoding: .ascii) ?? ""
        self.id = HeaderId.from(field: self.field)
        self.rawField = nameBytes
        self.encodingStorage = .utf8
        self.isInvalid = false
        self.rawValueStorage = rawValue
        self.textValue = nil
        self.explicitRawValue = false
    }

    /// Returns a string representation of the header.
    ///
    /// Formats the header field and value in a way that is suitable for display
    /// or writing to a message.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use. Defaults to ``FormatOptions/default``.
    ///   - encode: If `true`, the raw encoded value is included; otherwise, the
    ///             decoded value is used.
    ///
    /// - Returns: A string in the format "Field: Value" or just the raw content
    ///            for invalid headers.
    public func toString(_ options: FormatOptions = .default, encode: Bool = false) -> String {
        if isInvalid {
            let bytes = rawField + rawValueStorage
            var text = String(bytes: bytes, encoding: .ascii) ?? ""
            while text.hasSuffix("\n") || text.hasSuffix("\r") {
                text.removeLast()
            }
            return text
        }
        if encode {
            var raw = getRawValue(options)
            if raw.last == 0x0A {
                raw.removeLast()
                if raw.last == 0x0D {
                    raw.removeLast()
                }
            }
            let valueText = String(decoding: raw, as: UTF8.self)
            return "\(field):" + valueText
        }
        return "\(field): \(value)"
    }

    /// Gets the raw value of the header, optionally re-encoded with the specified format options.
    ///
    /// If the format options specify international encoding and the header value has not been
    /// explicitly set as raw bytes, this method may re-encode the header value according to
    /// the header type.
    ///
    /// - Parameter options: The formatting options to use.
    ///
    /// - Returns: The raw value as a byte array.
    public func getRawValue(_ options: FormatOptions) -> [UInt8] {
        if options.international && !explicitRawValue {
            switch id {
            case .dispositionNotificationTo, .resentReplyTo, .resentSender, .resentFrom, .resentBcc, .resentCc, .resentTo,
                    .replyTo, .sender, .from, .bcc, .cc, .to:
                return Header.reformatAddressHeader(options: self.options, format: options, field: field, rawValue: rawValueStorage)
            case .received:
                return rawValueStorage
            case .originalMessageId, .resentMessageId, .inReplyTo, .messageId, .contentId:
                return rawValueStorage
            case .references:
                return rawValueStorage
            case .contentDisposition:
                return Header.reformatContentDisposition(options: self.options, format: options, encoding: .utf8, field: field, rawValue: rawValueStorage)
            case .contentType:
                return Header.reformatContentType(options: self.options, format: options, encoding: .utf8, field: field, rawValue: rawValueStorage)
            case .dispositionNotificationOptions:
                return Header.encodeDispositionNotificationOptions(format: options, encoding: .utf8, field: field, value: value)
            case .listArchive, .listHelp, .listOwner, .listPost, .listSubscribe, .listUnsubscribe:
                return Header.encodeMailingListCommandHeader(options: self.options, format: options, encoding: .utf8, field: field, value: value)
            case .arcAuthenticationResults, .authenticationResults:
                return rawValueStorage
            case .dkimSignature, .arcMessageSignature, .arcSeal:
                return rawValueStorage
            default:
                return Header.encodeUnstructuredHeader(options: self.options, format: options, encoding: .utf8, field: field, value: value)
            }
        }
        return rawValueStorage
    }

    /// Gets the decoded header value using the specified character encoding.
    ///
    /// Decodes the raw header value using the specified character encoding for
    /// character set conversion.
    ///
    /// - Parameter encoding: The character encoding to use for decoding.
    ///
    /// - Returns: The decoded and unfolded header value.
    public func getValue(_ encoding: String.Encoding) -> String {
        var options = self.options
        options.charsetEncoding = encoding
        return Header.unfold(Rfc2047.decodeText(options, rawValueStorage, startIndex: 0, count: rawValueStorage.count))
    }

    /// Gets the decoded header value using the specified charset name.
    ///
    /// Decodes the raw header value using the specified charset for
    /// character set conversion.
    ///
    /// - Parameter charset: The name of the charset to use (e.g., "utf-8", "iso-8859-1").
    ///
    /// - Returns: The decoded and unfolded header value.
    ///
    /// - Throws: ``HeaderError/unsupportedCharset`` if the charset is not supported.
    public func getValue(_ charset: String) throws -> String {
        guard let encoding = CharsetUtils.getEncoding(charset) else {
            throw HeaderError.unsupportedCharset
        }
        return getValue(encoding)
    }

    /// Sets the header value using the specified formatting options and encoding.
    ///
    /// This method re-encodes the header value according to RFC 2047 using the
    /// specified character encoding.
    ///
    /// - Parameters:
    ///   - format: The formatting options to use when encoding the value.
    ///   - encoding: The character encoding to use.
    ///   - value: The new value for the header.
    public func setValue(_ format: FormatOptions, encoding: String.Encoding, value: String) {
        textValue = Header.unfold(value.trimmingCharacters(in: .whitespacesAndNewlines))
        rawValueStorage = Header.formatRawValue(options: options, format: format, encoding: encoding, field: field, id: id, value: textValue ?? "")
        explicitRawValue = false
        onChanged()
    }

    /// Sets the header value using the specified encoding.
    ///
    /// This method re-encodes the header value according to RFC 2047 using the
    /// specified character encoding with default formatting options.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to use.
    ///   - value: The new value for the header.
    public func setValue(_ encoding: String.Encoding, _ value: String) {
        setValue(.default, encoding: encoding, value: value)
    }

    /// Sets the header value using the specified charset name.
    ///
    /// - Parameters:
    ///   - format: The formatting options to use.
    ///   - charset: The name of the charset to use.
    ///   - value: The new value for the header.
    ///
    /// - Throws: ``HeaderError/unsupportedCharset`` if the charset is not supported.
    public func setValue(_ format: FormatOptions, charset: String, value: String) throws {
        guard let encoding = CharsetUtils.getEncoding(charset) else {
            throw HeaderError.unsupportedCharset
        }
        setValue(format, encoding: encoding, value: value)
    }

    /// Sets the header value using the specified charset name.
    ///
    /// - Parameters:
    ///   - charset: The name of the charset to use.
    ///   - value: The new value for the header.
    ///
    /// - Throws: ``HeaderError/unsupportedCharset`` if the charset is not supported.
    public func setValue(_ charset: String, _ value: String) throws {
        try setValue(.default, charset: charset, value: value)
    }

    /// Sets the raw value of the header directly from bytes.
    ///
    /// This method sets the raw value of the header without any encoding or
    /// transformation. The value must end with a newline character (0x0A).
    ///
    /// - Parameter value: The raw bytes to set as the header value.
    ///
    /// - Throws: ``HeaderError/invalidRawValue`` if the value is empty or
    ///           does not end with a newline.
    public func setRawValue(_ value: [UInt8]) throws {
        guard !value.isEmpty, value.last == 0x0A else {
            throw HeaderError.invalidRawValue
        }
        explicitRawValue = true
        rawValueStorage = value
        textValue = nil
        onChanged()
    }

    /// Creates a copy of the header.
    ///
    /// Creates a deep copy of the header including its raw value, text value,
    /// encoding, and invalid state.
    ///
    /// - Returns: A new ``Header`` instance with the same values as this header.
    public func copy() -> Header {
        let copied = Header(options, id, field, rawValueStorage)
        copied.explicitRawValue = explicitRawValue
        copied.textValue = textValue
        copied.encoding = encoding
        copied.isInvalid = isInvalid
        return copied
    }

    /// Unfolds a header value by removing line breaks.
    ///
    /// RFC 5322 allows header values to be folded across multiple lines for
    /// display purposes. This method removes those line breaks to produce
    /// a single-line value.
    ///
    /// - Parameter text: The text to unfold, or `nil`.
    ///
    /// - Returns: The unfolded text, or an empty string if the input was `nil`
    ///            or empty.
    public static func unfold(_ text: String?) -> String {
        guard let text, !text.isEmpty else {
            return ""
        }
        let scalars = Array(text.unicodeScalars)
        var start = 0
        while start < scalars.count, CharacterSet.whitespacesAndNewlines.contains(scalars[start]) {
            start += 1
        }
        if start >= scalars.count {
            return ""
        }

        var end = scalars.count - 1
        while end >= start, CharacterSet.whitespacesAndNewlines.contains(scalars[end]) {
            end -= 1
        }
        if end < start {
            return ""
        }

        var result = String.UnicodeScalarView()
        result.reserveCapacity(end - start + 1)
        for index in start...end {
            let scalar = scalars[index]
            if scalar.value != 0x0D && scalar.value != 0x0A {
                result.append(scalar)
            }
        }
        return String(result)
    }

    public var description: String {
        toString(.default, encode: false)
    }

    private func onChanged() {
        changed?(self)
    }

    /// Determines whether two headers are equal.
    ///
    /// Two headers are considered equal if they have the same identifier, field name,
    /// and decoded value.
    ///
    /// - Parameters:
    ///   - lhs: The first header to compare.
    ///   - rhs: The second header to compare.
    ///
    /// - Returns: `true` if the headers are equal; otherwise, `false`.
    public static func == (lhs: Header, rhs: Header) -> Bool {
        lhs.id == rhs.id && lhs.field == rhs.field && lhs.value == rhs.value
    }

    /// Compares two headers for ordering.
    ///
    /// Headers are ordered alphabetically by their field names, using
    /// case-insensitive comparison.
    ///
    /// - Parameters:
    ///   - lhs: The first header to compare.
    ///   - rhs: The second header to compare.
    ///
    /// - Returns: `true` if `lhs` should be ordered before `rhs`.
    public static func < (lhs: Header, rhs: Header) -> Bool {
        lhs.field.caseInsensitiveCompare(rhs.field) == .orderedAscending
    }

    /// Hashes the essential components of the header.
    ///
    /// The hash value is based on the lowercased field name.
    ///
    /// - Parameter hasher: The hasher to use.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(field.lowercased())
    }

    private static func isValidFieldName(_ field: String) -> Bool {
        for scalar in field.unicodeScalars {
            if scalar.value >= 127 {
                return false
            }
            let byte = UInt8(scalar.value)
            if !Header.isFieldText(byte) {
                return false
            }
        }
        return true
    }

    private static func isFieldText(_ byte: UInt8) -> Bool {
        if byte == 0x3A {
            return false
        }
        if byte < 0x21 || byte > 0x7E {
            return false
        }
        return true
    }
}

// MARK: - Formatting and parsing helpers
extension Header {
    /// Folds a header value to fit within the specified line length.
    ///
    /// RFC 5322 recommends that header lines be no longer than 78 characters.
    /// This method folds long values by inserting line breaks at appropriate
    /// positions.
    ///
    /// - Parameters:
    ///   - format: The formatting options, including the maximum line length.
    ///   - field: The header field name.
    ///   - value: The header value to fold.
    ///
    /// - Returns: The folded header value.
    public static func fold(_ format: FormatOptions, field: String, value: String) -> String {
        foldInternal(format, field: field, value: value)
    }

    private static func encodeAddressHeader(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        guard let list = try? InternetAddressList(parsing: value, options: options) else {
            return encodeUnstructuredHeader(options: options, format: format, encoding: encoding, field: field, value: value)
        }

        var builder = ""
        builder.append(" ")
        var lineLength = field.count + 2
        list.encode(format, builder: &builder, firstToken: true, lineLength: &lineLength)
        builder.append(format.newLine)
        return Array(builder.utf8)
    }

    private static func encodeMessageIdHeader(format: FormatOptions, encoding: String.Encoding, value: String) -> [UInt8] {
        let text = " " + value + format.newLine
        return Array(text.data(using: encoding) ?? Data())
    }

    private static func encodeReferencesHeader(format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        var encoded = ValueStringBuilder(initialCapacity: value.count + 8)
        var lineLength = field.count + 1
        var count = 0

        for reference in MimeUtils.enumerateReferences(value) {
            if count > 0 && lineLength + reference.count + 3 > format.maxLineLength {
                encoded.append(format.newLine)
                encoded.append("\t")
                lineLength = 1
                count = 0
            } else {
                encoded.append(" ")
                lineLength += 1
            }

            encoded.append("<")
            encoded.append(reference)
            encoded.append(">")
            lineLength += reference.count + 2
            count += 1
        }

        encoded.append(format.newLine)
        return Array(encoded.toString().data(using: encoding) ?? Data())
    }

    private static func encodeUnstructuredHeader(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        if format.international {
            if value.count <= format.maxLineLength {
                let text = " " + value + format.newLine
                return Array(text.utf8)
            }
            let folded = foldInternal(format, field: field, value: value)
            return Array(folded.utf8)
        }

        if shouldEncodeAsSingleWord(value) {
            let encodedWord = encodeSingleWord(encoding: encoding, text: value)
            let folded = foldUnstructuredHeader(format, field: field, text: Array(encodedWord.utf8))
            return folded
        }

        let encoded = Rfc2047.encodeText(format, encoding, value)
        let folded = foldUnstructuredHeader(format, field: field, text: encoded)
        return folded
    }

    private static func reformatAddressHeader(options: ParserOptions, format: FormatOptions, field: String, rawValue: [UInt8]) -> [UInt8] {
        guard let list = try? InternetAddressList(parsing: rawValue, options: options) else {
            return rawValue
        }

        var builder = ""
        builder.append(" ")
        var lineLength = field.count + 2
        list.encode(format, builder: &builder, firstToken: true, lineLength: &lineLength)
        builder.append(format.newLine)
        return Array(builder.utf8)
    }

    private static func reformatContentDisposition(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, rawValue: [UInt8]) -> [UInt8] {
        if let disposition = try? ContentDisposition(parsing: rawValue, options: options) {
            let encoded = disposition.encode(format, encoding)
            return Array(encoded.utf8)
        }
        return rawValue
    }

    private static func reformatContentType(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, rawValue: [UInt8]) -> [UInt8] {
        if let contentType = try? ContentType(parsing: rawValue, options: options) {
            let encoded = contentType.encode(format, encoding)
            return Array(encoded.utf8)
        }
        return rawValue
    }

    private static func encodeContentDisposition(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        if let disposition = try? ContentDisposition(parsing: value, options: options) {
            let encoded = disposition.encode(format, encoding)
            return Array(encoded.utf8)
        }
        return encodeUnstructuredHeader(options: options, format: format, encoding: encoding, field: field, value: value)
    }

    private static func encodeContentType(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        if let contentType = try? ContentType(parsing: value, options: options) {
            let encoded = contentType.encode(format, encoding)
            return Array(encoded.utf8)
        }
        return encodeUnstructuredHeader(options: options, format: format, encoding: encoding, field: field, value: value)
    }

    private static func encodeDispositionNotificationOptions(format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        var encoded = ValueStringBuilder(initialCapacity: value.count)
        var lineLength = field.count + 1
        var index = value.startIndex

        while index < value.endIndex {
            var parameter = ValueStringBuilder(initialCapacity: 128)

            while index < value.endIndex && Header.isWhiteSpace(value[index]) {
                index = value.index(after: index)
            }

            while index < value.endIndex && value[index] != ";" {
                if !Header.isWhiteSpace(value[index]) {
                    parameter.append(value[index])
                }
                index = value.index(after: index)
            }

            if index < value.endIndex && value[index] == ";" {
                parameter.append(";")
                index = value.index(after: index)
            }

            if lineLength + parameter.length + 1 > format.maxLineLength && encoded.length > 0 {
                encoded.append(format.newLine)
                encoded.append("\t")
                lineLength = 1
            } else {
                encoded.append(" ")
                lineLength += 1
            }

            encoded.append(parameter.asString())
            lineLength += parameter.length
        }

        encoded.append(format.newLine)
        return Array(encoded.toString().data(using: encoding) ?? Data())
    }

    private static func isMailingListCommandSpecial(_ ch: Character) -> Bool {
        ch == "<" || ch == "(" || ch == ","
    }

    private static func appendWord(format: FormatOptions, builder: inout ValueStringBuilder, lineLength: inout Int, word: String) {
        if lineLength + word.count + 1 <= format.maxLineLength {
            builder.append(" ")
            lineLength += 1
            builder.append(word)
            lineLength += word.count
        } else if word.count + 1 <= format.maxLineLength {
            builder.append(format.newLine)
            builder.append(" ")
            builder.append(word)
            lineLength = word.count + 1
        } else {
            var remaining = word.count
            var startIndex = word.startIndex
            while remaining > 0 {
                let available = max(format.maxLineLength - (lineLength + 1), 1)
                let length = min(remaining, available)
                let endIndex = word.index(startIndex, offsetBy: length)
                builder.append(" ")
                lineLength += 1
                builder.append(String(word[startIndex..<endIndex]))
                lineLength += length
                remaining -= length
                startIndex = endIndex
                if remaining > 0 {
                    builder.append(format.newLine)
                    lineLength = 0
                }
            }
        }
    }

    private static func appendComment(format: FormatOptions, encoding: String.Encoding, builder: inout ValueStringBuilder, lineLength: inout Int, value: String, startIndex: String.Index, endIndex: String.Index) {
        let raw = String(value[startIndex..<endIndex])
        let commentText: String

        if format.international {
            commentText = raw
        } else {
            let startOffset = value.distance(from: value.startIndex, to: startIndex)
            let length = value.distance(from: startIndex, to: endIndex)
            commentText = Rfc2047.encodeComment(format, encoding, value, startIndex: startOffset + 1, count: max(0, length - 2))
        }

        if lineLength + commentText.count + 1 <= format.maxLineLength {
            builder.append(" ")
            lineLength += 1
            builder.append(commentText)
            lineLength += commentText.count
        } else if commentText.count + 1 <= format.maxLineLength {
            builder.append(format.newLine)
            builder.append(" ")
            builder.append(commentText)
            lineLength = commentText.count + 1
        } else {
            var index = commentText.startIndex
            while index < commentText.endIndex {
                let slice = commentText[index...]
                let nextWhitespace = slice.firstIndex(where: { Header.isWhiteSpace($0) }) ?? commentText.endIndex
                let word = String(commentText[index..<nextWhitespace])
                appendWord(format: format, builder: &builder, lineLength: &lineLength, word: word)
                index = nextWhitespace
                while index < commentText.endIndex && Header.isWhiteSpace(commentText[index]) {
                    index = commentText.index(after: index)
                }
            }
        }
    }

    private static func encodeMailingListCommandHeader(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        var encoded = ValueStringBuilder(initialCapacity: value.count + 8)
        var lineLength = field.count + 1
        var index = value.startIndex

        while index < value.endIndex {
            while index < value.endIndex && Header.isWhiteSpace(value[index]) {
                index = value.index(after: index)
            }

            if index >= value.endIndex {
                break
            }

            let startIndex = index
            let ch = value[index]

            if ch == "<" {
                while index < value.endIndex && value[index] != ">" {
                    index = value.index(after: index)
                }
                if index < value.endIndex {
                    index = value.index(after: index)
                    let url = String(value[startIndex..<index])
                    if lineLength + url.count + 1 < format.maxLineLength {
                        encoded.append(" ")
                        lineLength += 1
                    } else {
                        encoded.append(format.newLine)
                        encoded.append(" ")
                        lineLength = 1
                    }
                    encoded.append(url)
                    lineLength += url.count
                    continue
                }
            } else if ch == "(" {
                var cursor = value.distance(from: value.startIndex, to: index)
                if ParseUtils.skipComment(value, index: &cursor, endIndex: value.count) {
                    let end = value.index(value.startIndex, offsetBy: cursor)
                    appendComment(format: format, encoding: encoding, builder: &encoded, lineLength: &lineLength, value: value, startIndex: startIndex, endIndex: end)
                    index = end
                    continue
                }
            } else if ch == "," {
                while index < value.endIndex && (value[index] == "," || Header.isWhiteSpace(value[index])) {
                    index = value.index(after: index)
                }
                encoded.append(",")
                lineLength += 1
                continue
            }

            while index < value.endIndex && !Header.isWhiteSpace(value[index]) && !isMailingListCommandSpecial(value[index]) {
                index = value.index(after: index)
            }
            let word = String(value[startIndex..<index])
            appendWord(format: format, builder: &encoded, lineLength: &lineLength, word: word)
        }

        encoded.append(format.newLine)
        return Array(encoded.toString().data(using: encoding) ?? Data())
    }

    private static func encodeReceivedHeader(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        let rawValue = Array(value.data(using: encoding) ?? Data())
        var tokens: [(start: Int, length: Int)] = []
        var index = 0
        var date = false

        func skipAtom(_ text: [UInt8], _ index: inout Int) {
            _ = (try? ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: text.count, throwOnError: false)) ?? false
            _ = ParseUtils.skipAtom(text, index: &index, endIndex: text.count)
        }

        func skipDomain(_ text: [UInt8], _ index: inout Int) {
            _ = (try? ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: text.count, throwOnError: false)) ?? false
            if index < text.count, text[index] == UInt8(ascii: "[") {
                while index < text.count && text[index] != UInt8(ascii: "]") {
                    index += 1
                }
                if index < text.count {
                    index += 1
                }
                return
            }
            while ParseUtils.skipAtom(text, index: &index, endIndex: text.count) && index < text.count && text[index] == UInt8(ascii: ".") {
                index += 1
            }
        }

        func skipAddress(_ text: [UInt8], _ index: inout Int) {
            _ = (try? ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: text.count, throwOnError: false)) ?? false
            if index < text.count, text[index] == UInt8(ascii: "<") {
                index += 1
            }
            if index >= text.count {
                return
            }
            var address: String? = nil
            var atIndex = 0
            _ = try? InternetAddress.tryParseAddrspec(text, index: &index, endIndex: text.count, sentinels: [UInt8(ascii: ">"), UInt8(ascii: ";")], compliance: .strict, throwOnError: false, addrspec: &address, at: &atIndex)
            if index < text.count, text[index] == UInt8(ascii: ">") {
                index += 1
            }
        }

        func skipMessageId(_ text: [UInt8], _ index: inout Int) {
            _ = (try? ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: text.count, throwOnError: false)) ?? false
            if index < text.count, text[index] == UInt8(ascii: "<") {
                index += 1
                if index >= text.count {
                    return
                }
                var address: String? = nil
                var atIndex = 0
                _ = try? InternetAddress.tryParseAddrspec(text, index: &index, endIndex: text.count, sentinels: [UInt8(ascii: ">")], compliance: .strict, throwOnError: false, addrspec: &address, at: &atIndex)
                if index < text.count, text[index] == UInt8(ascii: ">") {
                    index += 1
                }
            } else {
                _ = ParseUtils.skipAtom(text, index: &index, endIndex: text.count)
            }
        }

        while index < rawValue.count {
            let startIndex = index
            if !((try? ParseUtils.skipCommentsAndWhiteSpace(rawValue, index: &index, endIndex: rawValue.count, throwOnError: false)) ?? false) || index >= rawValue.count {
                tokens.append((start: startIndex, length: index - startIndex))
                break
            }

            while index < rawValue.count && !ByteClassification.isWhitespace(rawValue[index]) {
                index += 1
            }

            let atom = String(bytes: rawValue[startIndex..<index], encoding: encoding)?.lowercased() ?? ""
            var matched = true
            switch atom {
            case "from", "by", "via":
                skipDomain(rawValue, &index)
            case "with":
                skipAtom(rawValue, &index)
            case "id":
                skipMessageId(rawValue, &index)
            case "for":
                skipAddress(rawValue, &index)
            default:
                matched = false
            }

            if matched {
                if (try? ParseUtils.skipCommentsAndWhiteSpace(rawValue, index: &index, endIndex: rawValue.count, throwOnError: false)) == true {
                    if index < rawValue.count && rawValue[index] == UInt8(ascii: ";") {
                        date = true
                        index += 1
                    }
                }
                tokens.append((start: startIndex, length: index - startIndex))
            }

            if !matched {
                if (try? ParseUtils.skipCommentsAndWhiteSpace(rawValue, index: &index, endIndex: rawValue.count, throwOnError: false)) == true {
                    while index < rawValue.count && !ByteClassification.isWhitespace(rawValue[index]) {
                        index += 1
                    }
                }
                tokens.append((start: startIndex, length: index - startIndex))
            }

            _ = ParseUtils.skipWhiteSpace(rawValue, index: &index, endIndex: rawValue.count)

            if date && index < rawValue.count {
                tokens.append((start: index, length: rawValue.count - index))
                break
            }
        }

        var encoded = ValueStringBuilder(initialCapacity: rawValue.count + 8)
        var lineLength = field.count + 1
        var count = 0

        for token in tokens {
            let text = String(bytes: rawValue[token.start..<token.start + token.length], encoding: encoding)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if count > 0 && lineLength + text.count + 1 > format.maxLineLength {
                encoded.append(format.newLine)
                encoded.append("\t")
                lineLength = 1
                count = 0
            } else {
                encoded.append(" ")
                lineLength += 1
            }
            encoded.append(text)
            lineLength += text.count
            count += 1
        }

        encoded.append(format.newLine)
        return Array(encoded.toString().data(using: encoding) ?? Data())
    }

    private static func encodeDkimLongValue(_ format: FormatOptions, encoded: inout ValueStringBuilder, lineLength: inout Int, value: String) {
        var startIndex = value.startIndex
        while startIndex < value.endIndex {
            let lineLeft = format.maxLineLength - lineLength
            let endIndex = value.index(startIndex, offsetBy: min(lineLeft, value.distance(from: startIndex, to: value.endIndex)))
            encoded.append(String(value[startIndex..<endIndex]))
            lineLength += value.distance(from: startIndex, to: endIndex)
            if endIndex == value.endIndex {
                break
            }
            encoded.append(format.newLine)
            encoded.append("\t")
            lineLength = 1
            startIndex = endIndex
        }
    }

    private static func encodeDkimHeaderList(_ format: FormatOptions, encoded: inout ValueStringBuilder, lineLength: inout Int, value: String, delimiter: Character) {
        let tokens = value.split(separator: delimiter, omittingEmptySubsequences: false)
        for (idx, token) in tokens.enumerated() {
            if idx > 0 {
                encoded.append(String(delimiter))
                lineLength += 1
            }
            if lineLength + token.count + 1 > format.maxLineLength {
                encoded.append(format.newLine)
                encoded.append("\t")
                lineLength = 1
            }
            encoded.append(String(token))
            lineLength += token.count
        }
    }

    private static func encodeDkimOrArcSignatureHeader(format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        var encoded = ValueStringBuilder(initialCapacity: value.count + 8)
        var lineLength = field.count + 1
        var index = value.startIndex

        while index < value.endIndex {
            var token = ValueStringBuilder(initialCapacity: 128)

            while index < value.endIndex && Header.isWhiteSpace(value[index]) {
                index = value.index(after: index)
            }

            let startIndex = index
            while index < value.endIndex && value[index] != "=" {
                if !Header.isWhiteSpace(value[index]) {
                    token.append(value[index])
                }
                index = value.index(after: index)
            }

            let name = String(value[startIndex..<index])

            while index < value.endIndex && value[index] != ";" {
                if !Header.isWhiteSpace(value[index]) {
                    token.append(value[index])
                }
                index = value.index(after: index)
            }

            if index < value.endIndex && value[index] == ";" {
                token.append(";")
                index = value.index(after: index)
            }

            if lineLength + token.length + 1 > format.maxLineLength || name == "bh" || name == "b" {
                encoded.append(format.newLine)
                encoded.append("\t")
                lineLength = 1
            } else {
                encoded.append(" ")
                lineLength += 1
            }

            let tokenString = token.asString()
            if token.length > format.maxLineLength {
                if name == "z" {
                    encodeDkimHeaderList(format, encoded: &encoded, lineLength: &lineLength, value: tokenString, delimiter: "|")
                } else if name == "h" {
                    encodeDkimHeaderList(format, encoded: &encoded, lineLength: &lineLength, value: tokenString, delimiter: ":")
                } else {
                    encodeDkimLongValue(format, encoded: &encoded, lineLength: &lineLength, value: tokenString)
                }
            } else {
                encoded.append(tokenString)
                lineLength += token.length
            }
        }

        encoded.append(format.newLine)
        return Array(encoded.toString().data(using: encoding) ?? Data())
    }

    private static func encodeAuthenticationResultsHeader(format: FormatOptions, encoding: String.Encoding, field: String, value: String) -> [UInt8] {
        var tokens: [String] = []
        var current = ""
        for ch in value {
            if ch == ";" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    tokens.append(trimmed + ";")
                }
                current = ""
            } else {
                current.append(ch)
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tokens.append(trimmed)
        }

        var expanded: [String] = []
        for token in tokens {
            var valueToken = token
            var hasSemicolon = false
            if valueToken.hasSuffix(";") {
                valueToken.removeLast()
                hasSemicolon = true
            }

            if let open = valueToken.firstIndex(of: "("), let close = valueToken.lastIndex(of: ")"), open < close {
                let trimmedEnd = valueToken.trimmingCharacters(in: .whitespacesAndNewlines)
                let endsWithComment = trimmedEnd.lastIndex(of: ")") == trimmedEnd.index(before: trimmedEnd.endIndex)
                if !endsWithComment {
                    var combined = valueToken.trimmingCharacters(in: .whitespacesAndNewlines)
                    if hasSemicolon {
                        combined.append(";")
                    }
                    if !combined.isEmpty {
                        expanded.append(combined)
                    }
                    continue
                }
                let prefix = valueToken[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
                let comment = valueToken[open...close].trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.isEmpty {
                    expanded.append(prefix)
                }
                if !comment.isEmpty {
                    var commentToken = String(comment)
                    if hasSemicolon {
                        commentToken.append(";")
                        hasSemicolon = false
                    }
                    expanded.append(commentToken)
                }
                if hasSemicolon {
                    expanded.append(";")
                }
            } else {
                var combined = valueToken.trimmingCharacters(in: .whitespacesAndNewlines)
                if hasSemicolon {
                    combined.append(";")
                }
                if !combined.isEmpty {
                    expanded.append(combined)
                }
            }
        }

        var encoded = ValueStringBuilder(initialCapacity: value.count + 8)
        var lineLength = field.count + 1

        for (index, token) in expanded.enumerated() {
            let lower = token.lowercased()
            let forceNewLine = index > 0 && lower.hasPrefix("arc=")
            if forceNewLine || (index > 0 && lineLength + token.count + 1 > format.maxLineLength) {
                encoded.append(format.newLine)
                encoded.append("\t")
                lineLength = 1
            } else {
                encoded.append(" ")
                lineLength += 1
            }

            encoded.append(token)
            lineLength += token.count
        }

        encoded.append(format.newLine)
        return Array(encoded.toString().data(using: encoding) ?? Data())
    }

    private static func shouldEncodeAsSingleWord(_ value: String) -> Bool {
        var hasNonAscii = false
        for scalar in value.unicodeScalars {
            if scalar.value <= 0x7F {
                if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    return false
                }
            } else {
                hasNonAscii = true
            }
        }
        return hasNonAscii
    }

    private static func encodeSingleWord(encoding: String.Encoding, text: String) -> String {
        let bytes = CharsetUtils.getBytes(text, encoding: encoding)
        let qpEncoder = Rfc2047QuotedPrintableEncoder(mode: .text)
        let base64Encoder = Rfc2047Base64Encoder()
        let qpLength = qpEncoder.estimateOutputLength(bytes.count)
        let bLength = base64Encoder.estimateOutputLength(bytes.count)
        let encoder: any Rfc2047Encoder = (bLength < qpLength) ? base64Encoder : qpEncoder

        let outputLength = encoder.estimateOutputLength(bytes.count)
        var output = Array(repeating: UInt8(0), count: outputLength)
        let written = (try? encoder.encode(bytes, startIndex: 0, length: bytes.count, output: &output)) ?? 0
        let encodedText = String(bytes: Array(output[0..<written]), encoding: .ascii) ?? text
        let charset = CharsetUtils.getMimeCharset(encoding)
        let encodingLetter = String(encoder.encoding)
        return "=?\(charset)?\(encodingLetter)?\(encodedText)?="
    }

    private static func isWhiteSpace(_ ch: Character) -> Bool {
        ch == " " || ch == "\t" || ch == "\r" || ch == "\n"
    }

    private static func formatRawValue(options: ParserOptions, format: FormatOptions, encoding: String.Encoding, field: String, id: HeaderId, value: String) -> [UInt8] {
        switch id {
        case .dispositionNotificationTo, .resentReplyTo, .resentSender, .resentFrom, .resentBcc, .resentCc, .resentTo,
                .replyTo, .sender, .from, .bcc, .cc, .to:
            return encodeAddressHeader(options: options, format: format, encoding: encoding, field: field, value: value)
        case .received:
            return encodeReceivedHeader(options: options, format: format, encoding: encoding, field: field, value: value)
        case .originalMessageId, .resentMessageId, .inReplyTo, .messageId, .contentId:
            return encodeMessageIdHeader(format: format, encoding: encoding, value: value)
        case .references:
            return encodeReferencesHeader(format: format, encoding: encoding, field: field, value: value)
        case .contentDisposition:
            return encodeContentDisposition(options: options, format: format, encoding: encoding, field: field, value: value)
        case .contentType:
            return encodeContentType(options: options, format: format, encoding: encoding, field: field, value: value)
        case .dispositionNotificationOptions:
            return encodeDispositionNotificationOptions(format: format, encoding: encoding, field: field, value: value)
        case .arcAuthenticationResults, .authenticationResults:
            return encodeAuthenticationResultsHeader(format: format, encoding: encoding, field: field, value: value)
        case .dkimSignature, .arcMessageSignature, .arcSeal:
            return encodeDkimOrArcSignatureHeader(format: format, encoding: encoding, field: field, value: value)
        case .listArchive, .listHelp, .listOwner, .listPost, .listSubscribe, .listUnsubscribe:
            return encodeMailingListCommandHeader(options: options, format: format, encoding: encoding, field: field, value: value)
        default:
            return encodeUnstructuredHeader(options: options, format: format, encoding: encoding, field: field, value: value)
        }
    }

    private static func foldInternal(_ format: FormatOptions, field: String, value: String) -> String {
        var folded = ValueStringBuilder(initialCapacity: value.count + 8)
        var lineLength = field.count + 2
        var lastLwsp: Int? = nil

        folded.append(" ")

        for word in tokenizeText(value) {
            if Header.isWhiteSpace(word.first ?? " ") {
                if lineLength + word.count > format.maxLineLength {
                    for ch in word {
                        if lineLength > format.maxLineLength {
                            folded.append(format.newLine)
                            lineLength = 0
                        }
                        folded.append(ch)
                        lineLength += 1
                    }
                } else {
                    lineLength += word.count
                    folded.append(word)
                }
                lastLwsp = folded.length - 1
                continue
            }

            if let last = lastLwsp, lineLength + word.count > format.maxLineLength {
                folded.insert(format.newLine, at: last)
                lineLength = 1
                lastLwsp = nil
            }

            if word.count > format.maxLineLength {
                var index = word.startIndex
                while index < word.endIndex {
                    let remaining = word.distance(from: index, to: word.endIndex)
                    let allowed = max(format.maxLineLength - lineLength, 1)
                    let take = min(remaining, allowed)
                    let end = word.index(index, offsetBy: take)
                    if lineLength + take > format.maxLineLength {
                        folded.append(format.newLine)
                        folded.append(" ")
                        lineLength = 1
                    }
                    folded.append(String(word[index..<end]))
                    lineLength += take
                    index = end
                }
            } else {
                folded.append(word)
                lineLength += word.count
            }
        }

        folded.append(format.newLine)
        return folded.asString()
    }

    private static func tokenizeText(_ text: String) -> [String] {
        var tokens: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            let start = index
            if isWhiteSpace(ch) {
                while index < text.endIndex && isWhiteSpace(text[index]) {
                    index = text.index(after: index)
                }
            } else {
                while index < text.endIndex && !isWhiteSpace(text[index]) {
                    index = text.index(after: index)
                }
            }
            tokens.append(String(text[start..<index]))
        }
        return tokens
    }

    private static func foldUnstructuredHeader(_ format: FormatOptions, field: String, text: [UInt8]) -> [UInt8] {
        let value = String(bytes: text, encoding: .ascii) ?? String(decoding: text, as: UTF8.self)
        let folded = foldInternal(format, field: field, value: value)
        return Array(folded.utf8)
    }
}

// MARK: - Parsing
extension Header {
    /// Tries to parse a header from a byte buffer.
    ///
    /// Attempts to parse a header from the specified region of a byte buffer.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///   - length: The number of bytes to parse.
    ///   - header: On return, contains the parsed header if successful, or `nil` if parsing failed.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ options: ParserOptions, _ buffer: [UInt8], startIndex: Int, length: Int, header: inout Header?) -> Bool {
        let endIndex = startIndex + length
        guard startIndex >= 0, length >= 0, endIndex <= buffer.count else {
            header = nil
            return false
        }

        var index = startIndex
        while index < endIndex && Header.isFieldText(buffer[index]) {
            index += 1
        }

        let fieldNameLength = index - startIndex
        while index < endIndex && ByteClassification.isBlank(buffer[index]) {
            index += 1
        }

        guard index < endIndex, buffer[index] == UInt8(ascii: ":") else {
            header = nil
            return false
        }

        let rawField = Array(buffer[startIndex..<index])
        if fieldNameLength == 0 {
            header = nil
            return false
        }

        index += 1
        var rawValue = Array(buffer[index..<endIndex])
        if rawValue.last != 0x0A {
            rawValue.append(contentsOf: FormatOptions.default.newLineBytes)
        }

        header = Header(options, fieldBytes: rawField, fieldNameLength: fieldNameLength, rawValue: rawValue)
        return true
    }

    /// Tries to parse a header from a byte buffer using default options.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///   - length: The number of bytes to parse.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ buffer: [UInt8], startIndex: Int, length: Int, header: inout Header?) -> Bool {
        tryParse(.default, buffer, startIndex: startIndex, length: length, header: &header)
    }

    /// Tries to parse a header from a byte buffer, starting at the specified index.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ options: ParserOptions, _ buffer: [UInt8], startIndex: Int, header: inout Header?) -> Bool {
        tryParse(options, buffer, startIndex: startIndex, length: buffer.count - startIndex, header: &header)
    }

    /// Tries to parse a header from a byte buffer, starting at the specified index, using default options.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ buffer: [UInt8], startIndex: Int, header: inout Header?) -> Bool {
        tryParse(.default, buffer, startIndex: startIndex, length: buffer.count - startIndex, header: &header)
    }

    /// Tries to parse a header from an entire byte buffer.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - buffer: The byte buffer containing the header data.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ options: ParserOptions, _ buffer: [UInt8], header: inout Header?) -> Bool {
        tryParse(options, buffer, startIndex: 0, length: buffer.count, header: &header)
    }

    /// Tries to parse a header from an entire byte buffer using default options.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer containing the header data.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ buffer: [UInt8], header: inout Header?) -> Bool {
        tryParse(.default, buffer, startIndex: 0, length: buffer.count, header: &header)
    }

    /// Tries to parse a header from a string.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - text: The string containing the header data.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ options: ParserOptions, _ text: String, header: inout Header?) -> Bool {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        return tryParse(options, buffer, startIndex: 0, length: buffer.count, header: &header)
    }

    /// Tries to parse a header from a string using default options.
    ///
    /// - Parameters:
    ///   - text: The string containing the header data.
    ///   - header: On return, contains the parsed header if successful.
    ///
    /// - Returns: `true` if a header was successfully parsed; otherwise, `false`.
    public static func tryParse(_ text: String, header: inout Header?) -> Bool {
        tryParse(.default, text, header: &header)
    }

    /// Parses a header from a byte buffer.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///   - length: The number of bytes to parse.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the buffer does not contain a valid header.
    public static func parse(_ options: ParserOptions, _ buffer: [UInt8], startIndex: Int, length: Int) throws -> Header {
        var header: Header? = nil
        if tryParse(options, buffer, startIndex: startIndex, length: length, header: &header), let header {
            return header
        }
        throw ParseException("Invalid header.", tokenIndex: startIndex, errorIndex: startIndex)
    }

    /// Parses a header from a byte buffer using default options.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///   - length: The number of bytes to parse.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the buffer does not contain a valid header.
    public static func parse(_ buffer: [UInt8], startIndex: Int, length: Int) throws -> Header {
        try parse(.default, buffer, startIndex: startIndex, length: length)
    }

    /// Parses a header from a byte buffer, starting at the specified index.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the buffer does not contain a valid header.
    public static func parse(_ options: ParserOptions, _ buffer: [UInt8], startIndex: Int) throws -> Header {
        try parse(options, buffer, startIndex: startIndex, length: buffer.count - startIndex)
    }

    /// Parses a header from a byte buffer using default options, starting at the specified index.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer containing the header data.
    ///   - startIndex: The starting index in the buffer.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the buffer does not contain a valid header.
    public static func parse(_ buffer: [UInt8], startIndex: Int) throws -> Header {
        try parse(.default, buffer, startIndex: startIndex, length: buffer.count - startIndex)
    }

    /// Parses a header from an entire byte buffer.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - buffer: The byte buffer containing the header data.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the buffer does not contain a valid header.
    public static func parse(_ options: ParserOptions, _ buffer: [UInt8]) throws -> Header {
        try parse(options, buffer, startIndex: 0, length: buffer.count)
    }

    /// Parses a header from an entire byte buffer using default options.
    ///
    /// - Parameters:
    ///   - buffer: The byte buffer containing the header data.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the buffer does not contain a valid header.
    public static func parse(_ buffer: [UInt8]) throws -> Header {
        try parse(.default, buffer, startIndex: 0, length: buffer.count)
    }

    /// Parses a header from a string.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - text: The string containing the header data.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the string does not contain a valid header.
    public static func parse(_ options: ParserOptions, _ text: String) throws -> Header {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        return try parse(options, buffer, startIndex: 0, length: buffer.count)
    }

    /// Parses a header from a string using default options.
    ///
    /// - Parameters:
    ///   - text: The string containing the header data.
    ///
    /// - Returns: The parsed ``Header``.
    ///
    /// - Throws: ``ParseException`` if the string does not contain a valid header.
    public static func parse(_ text: String) throws -> Header {
        try parse(.default, text)
    }
}
