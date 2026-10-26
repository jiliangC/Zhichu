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
// MimePart.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation
import CryptoKit

/// Errors that can occur when working with MIME parts.
public enum MimePartError: Error, Equatable, Sendable {
    /// The media type is empty.
    case emptyMediaType

    /// The media subtype is empty.
    case emptyMediaSubtype

    /// The content duration is invalid (must be non-negative).
    case invalidContentDuration

    /// The encoding constraint is invalid.
    case invalidEncodingConstraint

    /// The content transfer encoding is invalid.
    case invalidContentTransferEncoding

    /// The part has no content.
    case noContent

    /// Cryptographic operations are not available.
    case cryptoUnavailable

    /// Duplicate content was specified.
    case duplicateContent

    /// An invalid argument was provided.
    case invalidArgument
}

/// A leaf-node MIME entity that contains a content body.
///
/// A `MimePart` is a leaf-node MIME entity, meaning it does not contain other
/// child entities. It contains content such as text, images, audio, video, or
/// other binary data.
///
/// The content of a `MimePart` is encapsulated in a `MimeContent` object
/// which can be accessed through the `content` property.
open class MimePart: MimeEntity {
    private static var octetStreamContentType: ContentType {
        guard let ct = try? ContentType("application", "octet-stream") else {
            preconditionFailure("Invalid static content type - this is a programming error")
        }
        return ct
    }

    private var contentDescriptionCache: String?
    private var contentDescriptionLoaded = false
    private var contentDurationCache: Int?
    private var contentDurationLoaded = false
    private var contentMd5Cache: String?
    private var contentMd5Loaded = false
    private var contentTransferEncodingCache: ContentEncoding = .default
    private var contentTransferEncodingLoaded = false

    /// The content of this MIME part.
    ///
    /// The `MimeContent` object encapsulates the content stream and provides
    /// methods for reading and decoding the content.
    public var content: MimeContent?

    /// The Content-Description header of this MIME part.
    ///
    /// The Content-Description header contains a textual description of the
    /// content, typically used to describe attachments.
    public var contentDescription: String? {
        get {
            if !contentDescriptionLoaded {
                if let header = headers.tryGetHeader(.contentDescription) {
                    contentDescriptionCache = header.value
                } else {
                    contentDescriptionCache = nil
                }
                contentDescriptionLoaded = true
            }
            return contentDescriptionCache
        }
        set {
            contentDescriptionLoaded = true
            contentDescriptionCache = newValue
            if let value = newValue {
                setHeader(.contentDescription, value)
            } else {
                removeHeader(.contentDescription)
            }
        }
    }

    /// The Content-Duration header of this MIME part.
    ///
    /// The Content-Duration header specifies the duration of audio or video
    /// content in seconds.
    public var contentDuration: Int? {
        get {
            if !contentDurationLoaded {
                if let header = headers.tryGetHeader(.contentDuration) {
                    contentDurationCache = Int(header.value)
                } else {
                    contentDurationCache = nil
                }
                contentDurationLoaded = true
            }
            return contentDurationCache
        }
        set {
            _ = try? setContentDuration(newValue)
        }
    }

    /// The Content-MD5 header of this MIME part.
    ///
    /// The Content-MD5 header contains a base64-encoded MD5 checksum of the
    /// content that can be used to verify content integrity.
    public var contentMd5: String? {
        get {
            if !contentMd5Loaded {
                if let header = headers.tryGetHeader(.contentMd5) {
                    contentMd5Cache = header.value
                } else {
                    contentMd5Cache = nil
                }
                contentMd5Loaded = true
            }
            return contentMd5Cache
        }
        set {
            contentMd5Loaded = true
            contentMd5Cache = newValue
            if let value = newValue {
                setHeader(.contentMd5, value)
            } else {
                removeHeader(.contentMd5)
            }
        }
    }

    /// The Content-Transfer-Encoding header of this MIME part.
    ///
    /// The Content-Transfer-Encoding header specifies how the content is
    /// encoded for transport (e.g., base64, quoted-printable).
    public var contentTransferEncoding: ContentEncoding {
        get {
            if !contentTransferEncodingLoaded {
                if let header = headers.tryGetHeader(.contentTransferEncoding) {
                    contentTransferEncodingCache = MimePart.parseContentEncoding(header.value)
                } else {
                    contentTransferEncodingCache = .default
                }
                contentTransferEncodingLoaded = true
            }
            return contentTransferEncodingCache
        }
        set {
            contentTransferEncodingLoaded = true
            contentTransferEncodingCache = newValue
            if newValue == .default {
                removeHeader(.contentTransferEncoding)
            } else {
                setHeader(.contentTransferEncoding, MimePart.formatContentEncoding(newValue))
            }
        }
    }

    /// Gets or sets whether this MIME part is an attachment.
    ///
    /// A value of `true` indicates that the part should be treated as an
    /// attachment rather than displayed inline. This property modifies the
    /// Content-Disposition header.
    public var isAttachment: Bool {
        get {
            contentDisposition?.isAttachment ?? false
        }
        set {
            if newValue {
                if contentDisposition == nil {
                    contentDisposition = try? ContentDisposition(ContentDisposition.attachment)
                }
                contentDisposition?.isAttachment = true
            } else if contentDisposition != nil {
                contentDisposition?.isAttachment = false
            }
        }
    }

    /// The suggested file name for this MIME part.
    ///
    /// Gets or sets the file name from the Content-Disposition header's filename
    /// parameter, falling back to the Content-Type's name parameter. When setting,
    /// both parameters are updated.
    public var fileName: String? {
        get {
            var name: String? = nil
            if let disposition = contentDisposition {
                name = disposition.fileName
            }
            return name ?? contentType.name
        }
        set {
            if let value = newValue {
                if contentDisposition == nil {
                    contentDisposition = try? ContentDisposition(ContentDisposition.attachment)
                }
                contentDisposition?.fileName = value
            } else {
                contentDisposition?.fileName = nil
            }
            contentType.name = newValue
        }
    }

    /// Initializes a new MIME part with the specified content type.
    ///
    /// - Parameter contentType: The content type for this MIME part.
    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    /// Initializes a new MIME part with the specified media type, subtype, and additional arguments.
    ///
    /// - Parameters:
    ///   - mediaType: The media type (e.g., "image", "audio").
    ///   - mediaSubtype: The media subtype (e.g., "jpeg", "mp3").
    ///   - args: Additional arguments such as headers or content.
    /// - Throws: An error if the media type or subtype is invalid.
    public convenience init(_ mediaType: String, _ mediaSubtype: String, _ args: Any...) throws {
        try self.init(mediaType, mediaSubtype, args: args)
    }

    /// Initializes a new MIME part with the specified media type, subtype, and array of arguments.
    ///
    /// - Parameters:
    ///   - mediaType: The media type (e.g., "image", "audio").
    ///   - mediaSubtype: The media subtype (e.g., "jpeg", "mp3").
    ///   - args: An array of additional arguments such as headers or content.
    /// - Throws: An error if the media type or subtype is invalid.
    public convenience init(_ mediaType: String, _ mediaSubtype: String, args: [Any?]) throws {
        guard !mediaType.isEmpty else {
            throw MimePartError.emptyMediaType
        }
        guard !mediaSubtype.isEmpty else {
            throw MimePartError.emptyMediaSubtype
        }
        let contentType = try ContentType(mediaType, mediaSubtype)
        self.init(contentType)
        var content: MimeContent?
        for arg in args {
            guard let arg else { continue }
            if tryInit(arg) {
                continue
            }
            if let mimeContent = arg as? MimeContent {
                if content != nil {
                    throw MimePartError.duplicateContent
                }
                content = mimeContent
                continue
            }
            if let stream = arg as? MimeStream {
                if content != nil {
                    throw MimePartError.duplicateContent
                }
                content = try MimeContent(stream: stream)
                continue
            }
            throw MimePartError.invalidArgument
        }
        if let content {
            self.content = content
        }
    }

    /// Initializes a new MIME part with the specified content type and additional arguments.
    ///
    /// - Parameters:
    ///   - contentType: The content type for this MIME part.
    ///   - args: Additional arguments such as headers.
    public convenience init(_ contentType: ContentType, _ args: Any...) {
        self.init(contentType)
        for arg in args {
            _ = tryInit(arg)
        }
    }

    /// Initializes a new MIME part with the specified media type and subtype.
    ///
    /// - Parameters:
    ///   - mediaType: The media type (e.g., "image", "audio").
    ///   - mediaSubtype: The media subtype (e.g., "jpeg", "mp3").
    /// - Throws: An error if the media type or subtype is invalid.
    public convenience init(_ mediaType: String, _ mediaSubtype: String) throws {
        try self.init(mediaType, mediaSubtype, args: [])
    }

    /// Initializes a new MIME part by parsing a MIME type string.
    ///
    /// - Parameter mimeType: The MIME type string (e.g., "image/jpeg").
    /// - Throws: An error if the MIME type string cannot be parsed.
    public convenience init(_ mimeType: String) throws {
        let parsed = try ContentType(parsing: mimeType)
        self.init(parsed)
    }

    /// Initializes a new MIME part with an application/octet-stream content type.
    public convenience init() {
        self.init(Self.octetStreamContentType)
    }

    internal func tryInit(_ obj: Any) -> Bool {
        if let header = obj as? Header {
            headers.add(header)
            return true
        }
        if let headers = obj as? [Header] {
            for header in headers {
                self.headers.add(header)
            }
            return true
        }
        return false
    }

    /// Computes the MD5 checksum of the content and updates the Content-MD5 header.
    ///
    /// - Returns: The base64-encoded MD5 checksum.
    /// - Throws: `MimePartError.noContent` if there is no content,
    ///           or `MimePartError.cryptoUnavailable` if MD5 is not available.
    public func computeContentMd5() throws -> String {
        guard let content else {
            throw MimePartError.noContent
        }
        let data = try readAllBytes(content: content)
        if #available(macOS 10.15, iOS 13.0, *) {
            let digest = Insecure.MD5.hash(data: Data(data))
            let md5Data = Data(digest)
            let encoded = md5Data.base64EncodedString()
            contentMd5 = encoded
            return encoded
        }
        throw MimePartError.cryptoUnavailable
    }

    /// Verifies the Content-MD5 checksum against the actual content.
    ///
    /// - Returns: `true` if the computed MD5 matches the Content-MD5 header,
    ///            `false` otherwise or if verification cannot be performed.
    public func verifyContentMd5() -> Bool {
        guard let expected = contentMd5 else {
            return false
        }
        guard let content else {
            return false
        }
        guard let data = try? readAllBytes(content: content) else {
            return false
        }
        if #available(macOS 10.15, iOS 13.0, *) {
            let digest = Insecure.MD5.hash(data: Data(data))
            let md5Data = Data(digest).base64EncodedString()
            return md5Data == expected
        }
        return false
    }

    /// Gets the best content transfer encoding for the specified constraint.
    ///
    /// Determines the optimal encoding based on the content and the transport
    /// constraint (7-bit, 8-bit, or binary).
    ///
    /// - Parameter constraint: The encoding constraint.
    /// - Returns: The recommended content encoding.
    /// - Throws: An error if the constraint is invalid.
    public func getBestEncoding(_ constraint: EncodingConstraint) throws -> ContentEncoding {
        switch constraint {
        case .sevenBit:
            return .base64
        case .eightBit:
            return .eightBit
        case .none:
            return contentTransferEncoding == .default ? .binary : contentTransferEncoding
        }
    }

    /// Prepares the MIME part for transport by setting an appropriate encoding.
    ///
    /// Analyzes the content and sets the Content-Transfer-Encoding header to
    /// an appropriate value based on the transport constraint.
    ///
    /// - Parameter constraint: The encoding constraint for transport.
    /// - Throws: An error if preparation fails.
    public func prepare(_ constraint: EncodingConstraint) throws {
        if constraint == .none {
            return
        }
        let best = try getBestEncoding(constraint)
        if contentTransferEncoding != best {
            contentTransferEncoding = best
        }
    }

    /// Sets the Content-Duration header value.
    ///
    /// - Parameter value: The duration in seconds, or `nil` to remove the header.
    /// - Throws: `MimePartError.invalidContentDuration` if the value is negative.
    public func setContentDuration(_ value: Int?) throws {
        contentDurationLoaded = true
        guard let value else {
            contentDurationCache = nil
            removeHeader(.contentDuration)
            return
        }
        if value < 0 {
            throw MimePartError.invalidContentDuration
        }
        contentDurationCache = value
        setHeader(.contentDuration, String(value))
    }

    /// Writes this MIME part to the specified stream.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - stream: The stream to write to.
    /// - Throws: An error if writing fails.
    open override func writeTo(_ options: FormatOptions, _ stream: MimeStream) throws {
        try super.writeTo(options, stream)
    }

    internal override func writeBody(_ options: FormatOptions, stream: MimeStream) throws {
        guard let content else { return }

        if content.encoding != contentTransferEncoding {
            if contentTransferEncoding == .uuEncode {
                let name = fileName ?? "unknown"
                let begin = Array("begin 0644 \(name)".utf8)
                try stream.write(begin, offset: 0, count: begin.count)
                let newLine = options.newLineBytes
                try stream.write(newLine, offset: 0, count: newLine.count)
            }

            let filtered = try FilteredStream(stream)
            let filter = EncoderFilter.create(contentTransferEncoding)
            _ = try filtered.add(filter)
            if contentTransferEncoding != .binary {
                try filtered.add(options.createNewLineFilter(ensureNewLine))
            }
            try content.decodeTo(filtered)
            try filtered.flush()

            if contentTransferEncoding == .uuEncode {
                let end = Array("end".utf8)
                let newLine = options.newLineBytes
                try stream.write(end, offset: 0, count: end.count)
                try stream.write(newLine, offset: 0, count: newLine.count)
            }
            return
        }

        if contentTransferEncoding == .binary {
            try content.writeTo(stream)
            return
        }

        let filtered = try FilteredStream(stream)
        try filtered.add(options.createNewLineFilter(ensureNewLine))
        try content.writeTo(filtered)
        try filtered.flush()
    }

    /// Accepts the visitor for processing this MIME part.
    ///
    /// - Parameter visitor: The visitor to accept.
    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    /// Called when the headers collection changes.
    ///
    /// - Parameters:
    ///   - action: The type of change that occurred.
    ///   - header: The header that was affected, or `nil` if headers were cleared.
    public override func headersChanged(_ action: HeaderListChangedAction, header: Header?) {
        super.headersChanged(action, header: header)

        switch action {
        case .cleared:
            contentDescriptionLoaded = false
            contentDurationLoaded = false
            contentMd5Loaded = false
            contentTransferEncodingLoaded = false
            return
        case .added, .changed, .removed:
            break
        }

        guard let header else { return }
        switch header.id {
        case .contentDescription:
            contentDescriptionLoaded = false
        case .contentDuration:
            contentDurationLoaded = false
        case .contentMd5:
            contentMd5Loaded = false
        case .contentTransferEncoding:
            contentTransferEncodingLoaded = false
        default:
            break
        }
    }

    internal func readAllBytes(content: MimeContent) throws -> [UInt8] {
        let stream = try content.open()
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data: [UInt8] = []
        while true {
            let read = try stream.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }

    private static func parseContentEncoding(_ value: String) -> ContentEncoding {
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

    private static func formatContentEncoding(_ encoding: ContentEncoding) -> String {
        switch encoding {
        case .sevenBit:
            return "7bit"
        case .eightBit:
            return "8bit"
        case .binary:
            return "binary"
        case .base64:
            return "base64"
        case .quotedPrintable:
            return "quoted-printable"
        case .uuEncode:
            return "x-uuencode"
        case .default:
            return ""
        }
    }
}
