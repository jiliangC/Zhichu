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
// MimeEntity.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with MIME entities.
public enum MimeEntityError: Error, Equatable, Sendable {
    /// The Content-Base value is not an absolute URI.
    case invalidContentBase

    /// The Content-Id value is not valid.
    case invalidContentId

    /// The MIME entity is invalid or could not be parsed.
    case invalidEntity
}

/// A protocol for visiting MIME entities using the visitor pattern.
///
/// The visitor pattern allows you to process different types of MIME entities
/// without modifying their classes. Implement this protocol to define custom
/// processing logic for each MIME entity type.
public protocol MimeVisitor {
    /// Visits a MIME message.
    /// - Parameter message: The MIME message to visit.
    func visit(_ message: MimeMessage)

    /// Visits a generic MIME entity.
    /// - Parameter entity: The MIME entity to visit.
    func visit(_ entity: MimeEntity)

    /// Visits a MIME part.
    /// - Parameter part: The MIME part to visit.
    func visit(_ part: MimePart)

    /// Visits a text part.
    /// - Parameter part: The text part to visit.
    func visit(_ part: TextPart)

    /// Visits a message part containing an embedded message.
    /// - Parameter part: The message part to visit.
    func visit(_ part: MessagePart)

    /// Visits a message delivery status report.
    /// - Parameter part: The delivery status to visit.
    func visit(_ part: MessageDeliveryStatus)

    /// Visits a message disposition notification.
    /// - Parameter part: The disposition notification to visit.
    func visit(_ part: MessageDispositionNotification)

    /// Visits a message feedback report.
    /// - Parameter part: The feedback report to visit.
    func visit(_ part: MessageFeedbackReport)

    /// Visits a partial message part.
    /// - Parameter part: The partial message to visit.
    func visit(_ part: MessagePartial)

    /// Visits an RFC 822 headers text part.
    /// - Parameter part: The headers text part to visit.
    func visit(_ part: TextRfc822Headers)

    /// Visits a TNEF part.
    /// - Parameter part: The TNEF part to visit.
    func visit(_ part: TnefPart)

    /// Visits a multipart entity.
    /// - Parameter multipart: The multipart to visit.
    func visit(_ multipart: Multipart)

    /// Visits a multipart/alternative entity.
    /// - Parameter multipart: The multipart/alternative to visit.
    func visit(_ multipart: MultipartAlternative)

    /// Visits a multipart/related entity.
    /// - Parameter multipart: The multipart/related to visit.
    func visit(_ multipart: MultipartRelated)

    /// Visits a multipart/report entity.
    /// - Parameter multipart: The multipart/report to visit.
    func visit(_ multipart: MultipartReport)

    /// Visits a PKCS#7 signature.
    /// - Parameter signature: The signature to visit.
    func visit(_ signature: ApplicationPkcs7Signature)

    /// Visits PKCS#7 encrypted MIME data.
    /// - Parameter encryptedMime: The encrypted MIME to visit.
    func visit(_ encryptedMime: ApplicationPkcs7Mime)

    /// Visits a multipart/signed entity.
    /// - Parameter signed: The signed multipart to visit.
    @available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
    func visit(_ signed: MultipartSigned)
}

/// Default implementations for MimeVisitor protocol methods.
public extension MimeVisitor {
    func visit(_ message: MimeMessage) {}
    func visit(_ entity: MimeEntity) {}
    func visit(_ part: MimePart) {}
    func visit(_ part: TextPart) {}
    func visit(_ part: MessagePart) {}
    func visit(_ part: MessageDeliveryStatus) {}
    func visit(_ part: MessageDispositionNotification) {}
    func visit(_ part: MessageFeedbackReport) {}
    func visit(_ part: MessagePartial) {}
    func visit(_ part: TextRfc822Headers) {}
    func visit(_ part: TnefPart) {}
    func visit(_ multipart: Multipart) {}
    func visit(_ multipart: MultipartAlternative) {}
    func visit(_ multipart: MultipartRelated) {}
    func visit(_ multipart: MultipartReport) {}
    func visit(_ signature: ApplicationPkcs7Signature) {}
    func visit(_ encryptedMime: ApplicationPkcs7Mime) {}
    @available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
    func visit(_ signed: MultipartSigned) {}
}

/// The base class for all MIME entities.
///
/// A MIME entity is really just a node in a tree structure representing the MIME message.
/// The body of a MIME entity is stored in the `MimePart` subclass.
///
/// All MIME entities have a `ContentType` header specifying the type of content contained
/// in the entity (text, image, video, etc). They may also contain `ContentDisposition`,
/// `ContentId`, `ContentLocation`, and `ContentBase` headers.
open class MimeEntity {
    /// The list of headers for this MIME entity.
    ///
    /// Represents the list of headers for a MIME entity. Modifying the headers
    /// in this list will automatically update the corresponding properties.
    public let headers: HeaderList

    /// The parser options used when parsing this entity.
    public let options: ParserOptions

    internal var ensureNewLine: Bool = false

    private var contentTypeStorage: ContentType
    private var contentDispositionCache: ContentDisposition?
    private var contentDispositionLoaded = false
    private var contentIdCache: String?
    private var contentIdLoaded = false
    private var contentLocationCache: URL?
    private var contentLocationLoaded = false
    private var contentBaseCache: URL?
    private var contentBaseLoaded = false

    private var isUpdatingHeaders = false

    /// The Content-Type header of this MIME entity.
    ///
    /// The Content-Type header specifies the media type and subtype of the content
    /// and may also contain optional parameters such as charset or boundary.
    public var contentType: ContentType {
        get { contentTypeStorage }
        set { setContentType(newValue, updateHeaders: true) }
    }

    /// The Content-Disposition header of this MIME entity.
    ///
    /// The Content-Disposition header is used to specify presentation information
    /// for the entity such as whether it should be displayed inline or as an attachment,
    /// along with an optional filename suggestion.
    public var contentDisposition: ContentDisposition? {
        get {
            if !contentDispositionLoaded {
                if let header = headers.tryGetHeader(.contentDisposition) {
                    let parsed = try? ContentDisposition(parsing: header.rawValue, options: options)
                    parsed?.changed = { [weak self] in
                        self?.updateContentDispositionHeader()
                    }
                    contentDispositionCache = parsed
                } else {
                    contentDispositionCache = nil
                }
                contentDispositionLoaded = true
            }
            return contentDispositionCache
        }
        set {
            contentDispositionLoaded = true
            if let value = newValue {
                value.changed = { [weak self] in
                    self?.updateContentDispositionHeader()
                }
                contentDispositionCache = value
                updateContentDispositionHeader()
            } else {
                contentDispositionCache = nil
                removeHeader(.contentDisposition)
            }
        }
    }

    /// The Content-Id header of this MIME entity.
    ///
    /// The Content-Id header is used to identify a particular entity and is
    /// often used in multipart/related messages to reference embedded resources.
    /// The value returned is the inner value without the angle brackets.
    public var contentId: String? {
        get {
            if !contentIdLoaded {
                if let header = headers.tryGetHeader(.contentId) {
                    contentIdCache = MimeEntity.parseMessageId(header.value)
                } else {
                    contentIdCache = nil
                }
                contentIdLoaded = true
            }
            return contentIdCache
        }
        set {
            _ = try? setContentId(newValue)
        }
    }

    /// The Content-Location header of this MIME entity.
    ///
    /// The Content-Location header specifies the URI for the entity.
    /// It may be either an absolute URI or a relative URI.
    public var contentLocation: URL? {
        get {
            if !contentLocationLoaded {
                if let header = headers.tryGetHeader(.contentLocation) {
                    contentLocationCache = URL(string: header.value)
                } else {
                    contentLocationCache = nil
                }
                contentLocationLoaded = true
            }
            return contentLocationCache
        }
        set {
            contentLocationLoaded = true
            if let value = newValue {
                contentLocationCache = value
                setHeader(.contentLocation, value.absoluteString)
            } else {
                contentLocationCache = nil
                removeHeader(.contentLocation)
            }
        }
    }

    /// The Content-Base header of this MIME entity.
    ///
    /// The Content-Base header specifies the base URI for resolving relative URIs
    /// contained in the Content-Location header or in the body of the entity.
    /// The value must be an absolute URI.
    public var contentBase: URL? {
        get {
            if !contentBaseLoaded {
                if let header = headers.tryGetHeader(.contentBase) {
                    contentBaseCache = URL(string: header.value)
                } else {
                    contentBaseCache = nil
                }
                contentBaseLoaded = true
            }
            return contentBaseCache
        }
        set {
            _ = try? setContentBase(newValue)
        }
    }

    /// Accepts the visitor for processing this entity.
    ///
    /// Implements the visitor design pattern, allowing external code to process
    /// this entity without subclassing.
    ///
    /// - Parameter visitor: The visitor to accept.
    open func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    /// Initializes a new MIME entity with the specified content type.
    ///
    /// - Parameter contentType: The content type for this entity.
    public init(_ contentType: ContentType) {
        self.options = .default
        self.headers = HeaderList()
        self.contentTypeStorage = contentType
        attachHandlers()
        updateContentTypeHeader()
    }

    /// Initializes a new MIME entity with the specified media type and subtype.
    ///
    /// - Parameters:
    ///   - mediaType: The media type (e.g., "text", "image", "application").
    ///   - mediaSubtype: The media subtype (e.g., "plain", "html", "jpeg").
    /// - Throws: An error if the media type or subtype is invalid.
    public convenience init(_ mediaType: String, _ mediaSubtype: String) throws {
        let contentType = try ContentType(mediaType, mediaSubtype)
        self.init(contentType)
    }

    private func attachHandlers() {
        headers.changed = { [weak self] action, header in
            self?.headersChanged(action, header: header)
        }
        contentTypeStorage.changed = { [weak self] in
            self?.updateContentTypeHeader()
        }
    }

    private func setContentType(_ contentType: ContentType, updateHeaders: Bool) {
        contentTypeStorage.changed = nil
        contentTypeStorage = contentType
        contentTypeStorage.changed = { [weak self] in
            self?.updateContentTypeHeader()
        }
        if updateHeaders {
            updateContentTypeHeader()
        }
    }

    private func updateContentTypeHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        let encoded = contentTypeStorage.encode(.default, .utf8)
        let value = MimeEntity.trimHeaderValue(encoded, newLine: FormatOptions.default.newLine)
        headers[.contentType] = value
        isUpdatingHeaders = false
    }

    private func updateContentDispositionHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let disposition = contentDispositionCache {
            let encoded = disposition.encode(.default, .utf8)
            let value = MimeEntity.trimHeaderValue(encoded, newLine: FormatOptions.default.newLine)
            headers[.contentDisposition] = value
        } else {
            removeHeader(.contentDisposition)
        }
        isUpdatingHeaders = false
    }

    /// Called when the headers collection changes.
    ///
    /// Subclasses should override this method to handle header changes
    /// and update cached property values accordingly.
    ///
    /// - Parameters:
    ///   - action: The type of change that occurred.
    ///   - header: The header that was affected, or `nil` if headers were cleared.
    open func headersChanged(_ action: HeaderListChangedAction, header: Header?) {
        guard !isUpdatingHeaders else { return }

        switch action {
        case .cleared:
            contentDispositionLoaded = false
            contentIdLoaded = false
            contentLocationLoaded = false
            contentBaseLoaded = false
            return
        case .added, .changed, .removed:
            break
        }

        guard let header else { return }
        switch header.id {
        case .contentType:
            if let parsed = try? ContentType(parsing: header.rawValue, options: options) {
                isUpdatingHeaders = true
                setContentType(parsed, updateHeaders: false)
                isUpdatingHeaders = false
            }
        case .contentDisposition:
            contentDispositionLoaded = false
        case .contentId:
            contentIdLoaded = false
        case .contentLocation:
            contentLocationLoaded = false
        case .contentBase:
            contentBaseLoaded = false
        default:
            break
        }
    }

    internal func setHeader(_ id: HeaderId, _ value: String) {
        headers[id] = value
    }

    internal func removeHeader(_ id: HeaderId) {
        headers.removeAll(id)
    }

    /// Writes this entity to the specified stream using default formatting options.
    ///
    /// - Parameter stream: The stream to write to.
    /// - Throws: An error if writing fails.
    public func writeTo(_ stream: MimeStream) throws {
        try writeTo(.default, stream)
    }

    /// Writes this entity to the specified stream using the specified formatting options.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - stream: The stream to write to.
    /// - Throws: An error if writing fails.
    public func writeTo(_ options: FormatOptions, _ stream: MimeStream) throws {
        try writeHeaders(options, stream: stream)
        try writeBody(options, stream: stream)
    }

    /// Writes this entity to a file using the specified formatting options.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - filePath: The path to the file to write.
    /// - Throws: An error if writing fails.
    public func writeTo(_ options: FormatOptions, _ filePath: String) throws {
        let memory = MemoryStream()
        try writeTo(options, memory)
        let data = Data(memory.toByteArray())
        try data.write(to: URL(fileURLWithPath: filePath))
    }

    /// Writes this entity to a file using default formatting options.
    ///
    /// - Parameter filePath: The path to the file to write.
    /// - Throws: An error if writing fails.
    public func writeTo(_ filePath: String) throws {
        try writeTo(.default, filePath)
    }

    /// Asynchronously writes this entity to the specified stream using default formatting options.
    ///
    /// - Parameter stream: The stream to write to.
    /// - Throws: An error if writing fails.
    public func writeToAsync(_ stream: MimeStream) async throws {
        try writeTo(.default, stream)
    }

    /// Asynchronously writes this entity to the specified stream using the specified formatting options.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - stream: The stream to write to.
    /// - Throws: An error if writing fails.
    public func writeToAsync(_ options: FormatOptions, _ stream: MimeStream) async throws {
        try writeTo(options, stream)
    }

    /// Asynchronously writes this entity to a file using the specified formatting options.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - filePath: The path to the file to write.
    /// - Throws: An error if writing fails.
    public func writeToAsync(_ options: FormatOptions, _ filePath: String) async throws {
        try writeTo(options, filePath)
    }

    /// Asynchronously writes this entity to a file using default formatting options.
    ///
    /// - Parameter filePath: The path to the file to write.
    /// - Throws: An error if writing fails.
    public func writeToAsync(_ filePath: String) async throws {
        try writeTo(.default, filePath)
    }

    /// Loads a MIME entity from a stream using default parser options.
    ///
    /// - Parameter stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading or parsing fails.
    public static func load(_ stream: MimeStream) throws -> MimeEntity {
        let bytes = try readAllBytes(from: stream)
        if let entity = try MimeMessage.parseEntity(.default, bytes) {
            return entity
        }
        throw MimeEntityError.invalidEntity
    }

    /// Loads a MIME entity from a stream using the specified parser options.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading or parsing fails.
    public static func load(_ options: ParserOptions, _ stream: MimeStream) throws -> MimeEntity {
        let bytes = try readAllBytes(from: stream)
        if let entity = try MimeMessage.parseEntity(options, bytes) {
            return entity
        }
        throw MimeEntityError.invalidEntity
    }

    /// Loads a MIME entity from a stream with a known content type.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the entity.
    ///   - stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading fails.
    public static func load(_ contentType: ContentType, _ stream: MimeStream) throws -> MimeEntity {
        let bytes = try readAllBytes(from: stream)
        let isText = contentType.isMimeType("text", "*")
        let part: MimePart = isText ? TextPart(contentType) : MimePart(contentType)
        part.content = MimeContent(MemoryStream(bytes, writable: false), encoding: part.contentTransferEncoding)
        return part
    }

    /// Loads a MIME entity from a stream with parser options and known content type.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - contentType: The content type of the entity.
    ///   - stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading fails.
    public static func load(_ options: ParserOptions, _ contentType: ContentType, _ stream: MimeStream) throws -> MimeEntity {
        if let custom = options.makeEntity(for: contentType) as? MimePart {
            let bytes = try readAllBytes(from: stream)
            custom.contentType = contentType
            custom.content = MimeContent(MemoryStream(bytes, writable: false), encoding: custom.contentTransferEncoding)
            return custom
        }
        return try load(contentType, stream)
    }

    /// Loads a MIME entity from a file using default parser options.
    ///
    /// - Parameter filePath: The path to the file to load.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading or parsing fails.
    public static func load(_ filePath: String) throws -> MimeEntity {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        return try load(MemoryStream(Array(data), writable: false))
    }

    /// Asynchronously loads a MIME entity from a stream using default parser options.
    ///
    /// - Parameter stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading or parsing fails.
    public static func loadAsync(_ stream: MimeStream) async throws -> MimeEntity {
        try load(stream)
    }

    /// Asynchronously loads a MIME entity from a stream using the specified parser options.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading or parsing fails.
    public static func loadAsync(_ options: ParserOptions, _ stream: MimeStream) async throws -> MimeEntity {
        try load(options, stream)
    }

    /// Asynchronously loads a MIME entity from a stream with a known content type.
    ///
    /// - Parameters:
    ///   - contentType: The content type of the entity.
    ///   - stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading fails.
    public static func loadAsync(_ contentType: ContentType, _ stream: MimeStream) async throws -> MimeEntity {
        try load(contentType, stream)
    }

    /// Asynchronously loads a MIME entity from a stream with parser options and known content type.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - contentType: The content type of the entity.
    ///   - stream: The stream to load from.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading fails.
    public static func loadAsync(_ options: ParserOptions, _ contentType: ContentType, _ stream: MimeStream) async throws -> MimeEntity {
        try load(options, contentType, stream)
    }

    /// Asynchronously loads a MIME entity from a file using default parser options.
    ///
    /// - Parameter filePath: The path to the file to load.
    /// - Returns: The loaded MIME entity.
    /// - Throws: An error if loading or parsing fails.
    public static func loadAsync(_ filePath: String) async throws -> MimeEntity {
        try load(filePath)
    }

    private static func readAllBytes(from stream: MimeStream) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data: [UInt8] = []
        _ = try? stream.seek(0, origin: .begin)
        while true {
            let read = try stream.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }

    internal func writeHeaders(_ options: FormatOptions, stream: MimeStream) throws {
        var headerOptions = options
        headerOptions.ensureNewLine = false
        var text = headers.toString(headerOptions, encode: true)
        text.append(options.newLine)
        text.append(options.newLine)
        let bytes = Array(text.utf8)
        try stream.write(bytes, offset: 0, count: bytes.count)
    }

    internal func writeBody(_ options: FormatOptions, stream: MimeStream) throws {
        // Default: no body for base entity.
    }

    private static func trimHeaderValue(_ encoded: String, newLine: String) -> String {
        var trimmed = encoded
        while trimmed.hasSuffix(newLine) {
            trimmed.removeLast(newLine.count)
        }
        if trimmed.hasPrefix(" ") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    /// Sets the Content-Id header value.
    ///
    /// - Parameter value: The content ID value, or `nil` to remove the header.
    /// - Throws: `MimeEntityError.invalidContentId` if the value is not a valid message ID.
    public func setContentId(_ value: String?) throws {
        contentIdLoaded = true
        guard let value else {
            contentIdCache = nil
            removeHeader(.contentId)
            return
        }
        guard let parsed = MimeEntity.parseMessageId(value) else {
            throw MimeEntityError.invalidContentId
        }
        contentIdCache = parsed
        setHeader(.contentId, "<\(parsed)>")
    }

    /// Sets the Content-Base header value.
    ///
    /// - Parameter value: The base URI, or `nil` to remove the header. Must be an absolute URI.
    /// - Throws: `MimeEntityError.invalidContentBase` if the value is not an absolute URI.
    public func setContentBase(_ value: URL?) throws {
        contentBaseLoaded = true
        if let value {
            guard value.scheme != nil else {
                throw MimeEntityError.invalidContentBase
            }
            contentBaseCache = value
            setHeader(.contentBase, value.absoluteString)
        } else {
            contentBaseCache = nil
            removeHeader(.contentBase)
        }
    }

    internal static func parseMessageId(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        if trimmed.hasPrefix("<") {
            guard trimmed.hasSuffix(">") else {
                return nil
            }
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            let inner = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            return inner.isEmpty ? nil : String(inner)
        }
        if trimmed.contains("<") || trimmed.contains(">") {
            return nil
        }
        return trimmed
    }
}
