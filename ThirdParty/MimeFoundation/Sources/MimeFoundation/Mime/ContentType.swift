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
// ContentType.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with Content-Type values.
public enum ContentTypeError: Error, Sendable {
    /// The media type is invalid or empty.
    case invalidMediaType

    /// The media subtype is invalid or empty.
    case invalidMediaSubtype
}

/// A MIME Content-Type header value.
///
/// The Content-Type header specifies the media type and subtype of the content,
/// along with optional parameters such as charset or boundary. This class provides
/// convenient access to the media type, subtype, and commonly-used parameters.
///
/// ## Topics
///
/// ### Creating Content Types
/// - ``init(_:_:)``
///
/// ### Media Type
/// - ``mediaType``
/// - ``mediaSubtype``
/// - ``mimeType``
/// - ``setMediaType(_:)``
/// - ``setMediaSubtype(_:)``
/// - ``isMimeType(_:_:)``
///
/// ### Parameters
/// - ``parameters``
/// - ``boundary``
/// - ``charset``
/// - ``charsetEncoding``
/// - ``format``
/// - ``name``
///
/// ### Encoding and Formatting
/// - ``encode(_:_:)``
/// - ``copy()``
public final class ContentType: Equatable {
    private var type: String
    private var subtype: String

    /// The list of parameters on the Content-Type header.
    ///
    /// Parameters provide additional information about the content type, such as
    /// charset for text content or boundary for multipart content.
    public var parameters: ParameterList {
        didSet {
            parameters.changed = { [weak self] _ in
                self?.onChanged()
            }
            onChanged()
        }
    }

    /// Initializes a new Content-Type with the specified media type and subtype.
    ///
    /// - Parameters:
    ///   - mediaType: The media type (e.g., "text", "image", "application").
    ///   - mediaSubtype: The media subtype (e.g., "plain", "html", "jpeg").
    /// - Throws: ``ContentTypeError/invalidMediaType`` if the media type is empty,
    ///           or ``ContentTypeError/invalidMediaSubtype`` if the media subtype is empty.
    public init(_ mediaType: String, _ mediaSubtype: String) throws {
        if mediaType.isEmpty {
            throw ContentTypeError.invalidMediaType
        }
        if mediaSubtype.isEmpty {
            throw ContentTypeError.invalidMediaSubtype
        }
        self.type = mediaType
        self.subtype = mediaSubtype
        self.parameters = ParameterList()
        self.parameters.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    /// Internal initializer for cloning. Assumes values are already validated.
    private init(cloning mediaType: String, _ mediaSubtype: String) {
        self.type = mediaType
        self.subtype = mediaSubtype
        self.parameters = ParameterList()
        self.parameters.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    /// The media type of the Content-Type.
    ///
    /// The media type is the first part of the MIME type (e.g., "text" in "text/plain").
    public var mediaType: String {
        get { type }
        set {
            if newValue.isEmpty {
                return
            }
            if type == newValue {
                return
            }
            type = newValue
            onChanged()
        }
    }

    /// The media subtype of the Content-Type.
    ///
    /// The media subtype is the second part of the MIME type (e.g., "plain" in "text/plain").
    public var mediaSubtype: String {
        get { subtype }
        set {
            if newValue.isEmpty {
                return
            }
            if subtype == newValue {
                return
            }
            subtype = newValue
            onChanged()
        }
    }

    /// The boundary parameter value, if present.
    ///
    /// The boundary is used in multipart entities to delimit the parts.
    /// This is a convenience property for accessing the "boundary" parameter.
    public var boundary: String? {
        get { parameters["boundary"] }
        set {
            if parameters["boundary"] == newValue {
                return
            }
            parameters["boundary"] = newValue
        }
    }

    /// The charset parameter value, if present.
    ///
    /// The charset specifies the character encoding used for text content.
    /// This is a convenience property for accessing the "charset" parameter.
    public var charset: String? {
        get { parameters["charset"] }
        set {
            if parameters["charset"] == newValue {
                return
            }
            parameters["charset"] = newValue
        }
    }

    /// The charset as a Swift string encoding, if present.
    ///
    /// Gets or sets the charset parameter value as a Swift `String.Encoding`.
    /// When getting, returns the encoding corresponding to the charset parameter,
    /// or `nil` if the charset is not set or not recognized.
    public var charsetEncoding: String.Encoding? {
        get {
            guard let charset else { return nil }
            return CharsetUtils.getEncoding(charset)
        }
        set {
            charset = newValue != nil ? CharsetUtils.getMimeCharset(newValue!) : nil
        }
    }

    /// The format parameter value, if present.
    ///
    /// The format parameter is used for additional type information,
    /// such as "flowed" for text/plain with format=flowed.
    /// This is a convenience property for accessing the "format" parameter.
    public var format: String? {
        get { parameters["format"] }
        set {
            if parameters["format"] == newValue {
                return
            }
            parameters["format"] = newValue
        }
    }

    /// The name parameter value, if present.
    ///
    /// The name parameter suggests a filename for the content.
    /// This is a convenience property for accessing the "name" parameter.
    public var name: String? {
        get { parameters["name"] }
        set {
            if parameters["name"] == newValue {
                return
            }
            parameters["name"] = newValue
        }
    }

    /// The complete MIME type string.
    ///
    /// Returns the media type and subtype joined with a slash (e.g., "text/plain").
    public var mimeType: String {
        "\(type)/\(subtype)"
    }

    /// Checks whether this Content-Type matches the specified media type and subtype.
    ///
    /// - Parameters:
    ///   - mediaType: The media type to match (use "*" for wildcard).
    ///   - mediaSubtype: The media subtype to match (use "*" for wildcard).
    /// - Returns: `true` if this Content-Type matches; otherwise, `false`.
    public func isMimeType(_ mediaType: String, _ mediaSubtype: String) -> Bool {
        if mediaType == "*" || mediaType.caseInsensitiveCompare(type) == .orderedSame {
            return mediaSubtype == "*" || mediaSubtype.caseInsensitiveCompare(subtype) == .orderedSame
        }
        return false
    }

    public func setMediaType(_ value: String) throws {
        if value.isEmpty {
            throw ContentTypeError.invalidMediaType
        }
        if type != value {
            type = value
            onChanged()
        }
    }

    public func setMediaSubtype(_ value: String) throws {
        if value.isEmpty {
            throw ContentTypeError.invalidMediaSubtype
        }
        if subtype != value {
            subtype = value
            onChanged()
        }
    }

    public var changed: (() -> Void)?

    private func onChanged() {
        changed?()
    }

    public func copy() -> ContentType {
        let copied = ContentType(cloning: type, subtype)
        for param in parameters {
            try? copied.parameters.add(param.copy())
        }
        return copied
    }

    public func toString(_ options: FormatOptions, _ encoding: String.Encoding, _ encode: Bool) -> String {
        var builder = ValueStringBuilder(initialCapacity: 128)
        builder.append("Content-Type: ")
        builder.append(type)
        builder.append("/")
        builder.append(subtype)
        if encode {
            var lineLength = builder.length
            parameters.encode(options, builder: &builder, lineLength: &lineLength, charset: encoding)
        } else {
            parameters.writeTo(&builder)
        }
        return builder.toString()
    }

    public func toString(_ encoding: String.Encoding, _ encode: Bool) -> String {
        toString(FormatOptions.default, encoding, encode)
    }

    public func toString(_ encode: Bool) -> String {
        (try? toString(FormatOptions.default, .utf8, encode)) ?? ""
    }

    public func toString() -> String {
        toString(false)
    }

    public func encode(_ options: FormatOptions, _ charset: String.Encoding) -> String {
        let lineLength = "Content-Type:".count
        var builder = ValueStringBuilder(initialCapacity: 128)
        builder.append(" ")
        builder.append(type)
        builder.append("/")
        builder.append(subtype)
        var currentLength = lineLength + builder.length
        parameters.encode(options, builder: &builder, lineLength: &currentLength, charset: charset)
        builder.append(options.newLine)
        return builder.asString()
    }

    private static func skipType(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let start = index
        while index < endIndex && ByteClassification.isAsciiAtom(text[index]) && text[index] != UInt8(ascii: "/") {
            index += 1
        }
        return index > start
    }

    private static func skipSubtype(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let start = index
        while index < endIndex && (ByteClassification.isToken(text[index]) || text[index] == UInt8(ascii: "/")) {
            index += 1
        }
        return index > start
    }

    internal static func tryParse(
        _ options: ParserOptions,
        _ text: [UInt8],
        index: inout Int,
        endIndex: Int,
        throwOnError: Bool,
        contentType: inout ContentType?
    ) throws -> Bool {
        contentType = nil

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        let start = index
        if !skipType(text, index: &index, endIndex: endIndex) {
            if throwOnError {
                throw ParseException("Invalid type token at position \(start)", tokenIndex: start, errorIndex: index)
            }
            return false
        }

        let type = String(bytes: text[start..<index], encoding: .ascii) ?? ""

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex || text[index] != UInt8(ascii: "/") {
            if throwOnError {
                throw ParseException("Expected '/' at position \(index)", tokenIndex: index, errorIndex: index)
            }
            return false
        }

        index += 1

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        let subtypeStart = index
        if !skipSubtype(text, index: &index, endIndex: endIndex) {
            if throwOnError {
                throw ParseException("Invalid atom token at position \(subtypeStart)", tokenIndex: subtypeStart, errorIndex: index)
            }
            return false
        }

        let subtype = String(bytes: text[subtypeStart..<index], encoding: .ascii) ?? ""

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        contentType = try ContentType(type, subtype)

        if index >= endIndex {
            return true
        }

        if text[index] != UInt8(ascii: ";") {
            if throwOnError {
                throw ParseException("Expected ';' at position \(index)", tokenIndex: index, errorIndex: index)
            }
            return false
        }

        index += 1

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex {
            return true
        }

        var params: ParameterList? = nil
        if !(try ParameterList.tryParse(options, text, index: &index, endIndex: endIndex, throwOnError: throwOnError, paramList: &params)) {
            return false
        }

        if let params {
            contentType?.parameters = params
        }

        return true
    }

    // MARK: - Swift-Idiomatic Parsing Initializers

    /// Throwing initializer - throws ParseException on failure.
    /// Use `try?` for optional behavior: `let ct = try? ContentType(parsing: text)`
    public convenience init(parsing text: String, options: ParserOptions = .default) throws {
        let buffer = Array(text.utf8)
        try self.init(parsing: buffer, options: options)
    }

    /// Throwing initializer - throws ParseException on failure.
    /// Use `try?` for optional behavior: `let ct = try? ContentType(parsing: buffer)`
    public convenience init(parsing buffer: [UInt8], options: ParserOptions = .default) throws {
        var result: ContentType? = nil
        var index = 0

        // First try with throwOnError: false to allow lenient parsing
        if !(try Self.tryParse(options, buffer, index: &index, endIndex: buffer.count,
                              throwOnError: false, contentType: &result)) {
            // If that fails, try with throwOnError: true to get the proper exception
            index = 0
            _ = try Self.tryParse(options, buffer, index: &index, endIndex: buffer.count,
                                  throwOnError: true, contentType: &result)
        }

        guard let parsed = result else {
            throw ParseException("Failed to parse content type.", tokenIndex: 0, errorIndex: index)
        }
        try self.init(parsed.mediaType, parsed.mediaSubtype)
        self.parameters = parsed.parameters
    }

    public static func == (lhs: ContentType, rhs: ContentType) -> Bool {
        lhs.type.caseInsensitiveCompare(rhs.type) == .orderedSame &&
        lhs.subtype.caseInsensitiveCompare(rhs.subtype) == .orderedSame &&
        lhs.parameters == rhs.parameters
    }
}
