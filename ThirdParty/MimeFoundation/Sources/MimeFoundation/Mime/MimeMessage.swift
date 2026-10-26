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
// MimeMessage.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with MIME messages.
public enum MimeMessageError: Error, Equatable, Sendable {
    /// The maximum line length value is invalid.
    case invalidMaxLineLength

    /// A duplicate body was specified when creating the message.
    case duplicateBody

    /// An invalid argument was provided.
    case invalidArgument

    /// The Message-Id value is not valid.
    case invalidMessageId

    /// The Resent-Message-Id value is not valid.
    case invalidResentMessageId

    /// The In-Reply-To value is not valid.
    case invalidInReplyTo
}

/// A MIME message.
///
/// A message consists of header fields and, optionally, a body. The body of the message
/// can either be plain text or it can be a tree of MIME entities such as a text/plain
/// MIME part and a collection of file attachments.
///
/// ## Topics
///
/// ### Creating Messages
/// - ``init()``
/// - ``init(_:)``
/// - ``init(args:)``
/// - ``init(headers:)``
/// - ``init(from:to:subject:body:)``
///
/// ### Headers and Addresses
/// - ``headers``
/// - ``from``
/// - ``to``
/// - ``cc``
/// - ``bcc``
/// - ``replyTo``
/// - ``sender``
/// - ``resentFrom``
/// - ``resentTo``
/// - ``resentCc``
/// - ``resentBcc``
/// - ``resentReplyTo``
/// - ``resentSender``
///
/// ### Message Properties
/// - ``subject``
/// - ``date``
/// - ``resentDate``
/// - ``messageId``
/// - ``resentMessageId``
/// - ``inReplyTo``
/// - ``references``
/// - ``mimeVersion``
/// - ``body``
///
/// ### Priority and Importance
/// - ``importance``
/// - ``priority``
/// - ``xPriority``
///
/// ### Working with Content
/// - ``textBody``
/// - ``htmlBody``
/// - ``getTextBody(_:)``
/// - ``bodyParts``
/// - ``attachments``
/// - ``getRecipients(_:)``
///
/// ### Writing and Loading
/// - ``writeTo(_:)``
/// - ``writeTo(_:_:)``
/// - ``load(_:)``
/// - ``load(_:_:)``
/// - ``prepare(_:maxLineLength:)``
///
/// ### Visiting
/// - ``accept(_:)``
public final class MimeMessage {
    /// The list of headers for this message.
    ///
    /// Represents the list of headers for a message. Typically, the headers of
    /// a message will contain transmission headers such as From and To along
    /// with metadata headers such as Subject and Date, but may include just
    /// about anything.
    ///
    /// - Note: To access any MIME headers such as Content-Type, Content-Disposition,
    ///   Content-Transfer-Encoding or any other Content-* header, you will need to
    ///   access the ``MimeEntity/headers`` property of the ``body``.
    public let headers: HeaderList

    /// The body of the message.
    ///
    /// The body can be any MIME entity, including a multipart container with nested
    /// parts, a text part, or a message part.
    public var body: MimeEntity?

    /// The list of addresses in the From header.
    ///
    /// The "From" field specifies the author(s) of the message.
    public let from: InternetAddressList

    /// The list of addresses in the To header.
    ///
    /// The "To" field specifies the primary recipient(s) of the message.
    public let to: InternetAddressList

    /// The list of addresses in the Cc header.
    ///
    /// The "Cc" field specifies the carbon-copy recipient(s) of the message.
    public let cc: InternetAddressList

    /// The list of addresses in the Reply-To header.
    ///
    /// When the sender of the message wants replies to go to a different address,
    /// the Reply-To header is used to specify those addresses.
    public let replyTo: InternetAddressList

    /// The list of addresses in the Bcc header.
    ///
    /// The "Bcc" field specifies the blind carbon-copy recipient(s) of the message.
    /// Recipients in the Bcc list are not visible to other recipients.
    public let bcc: InternetAddressList

    /// The list of addresses in the Resent-From header.
    ///
    /// When a message is resent, the Resent-From header specifies the author(s)
    /// of the resent message.
    public let resentFrom: InternetAddressList

    /// The list of addresses in the Resent-Reply-To header.
    ///
    /// When a message is resent and replies should go to a different address,
    /// the Resent-Reply-To header is used to specify those addresses.
    public let resentReplyTo: InternetAddressList

    /// The list of addresses in the Resent-To header.
    ///
    /// When a message is resent, the Resent-To header specifies the primary
    /// recipient(s) of the resent message.
    public let resentTo: InternetAddressList

    /// The list of addresses in the Resent-Cc header.
    ///
    /// When a message is resent, the Resent-Cc header specifies the carbon-copy
    /// recipient(s) of the resent message.
    public let resentCc: InternetAddressList

    /// The list of addresses in the Resent-Bcc header.
    ///
    /// When a message is resent, the Resent-Bcc header specifies the blind
    /// carbon-copy recipient(s) of the resent message.
    public let resentBcc: InternetAddressList

    /// The list of message identifiers in the References header.
    ///
    /// The "References" field lists the message identifiers of messages to which
    /// this message is related, typically used in threading.
    public let references: MessageIdList

    private var subjectStorage: String?
    private var dateStorage: DateTimeOffset?
    private var resentDateStorage: DateTimeOffset?
    private var senderStorage: MailboxAddress?
    private var resentSenderStorage: MailboxAddress?
    private var messageIdStorage: String?
    private var resentMessageIdStorage: String?
    private var inReplyToStorage: String?
    private var mimeVersionStorage: MimeVersion?
    private var importanceStorage: MessageImportance = .normal
    private var priorityStorage: MessagePriority = .normal
    private var xPriorityStorage: XMessagePriority = .normal
    private var isUpdatingHeaders = false

    /// The subject of the message.
    ///
    /// The "Subject" field contains a short string identifying the topic of the message.
    public var subject: String? {
        get { subjectStorage }
        set {
            subjectStorage = newValue
            updateSubjectHeader()
        }
    }

    /// The date of the message.
    ///
    /// The "Date" field specifies the date and time at which the message was written.
    public var date: DateTimeOffset? {
        get { dateStorage }
        set {
            dateStorage = newValue
            updateDateHeader()
        }
    }

    /// The date the message was resent.
    ///
    /// The "Resent-Date" field specifies the date and time at which the message was resent.
    public var resentDate: DateTimeOffset? {
        get { resentDateStorage }
        set {
            resentDateStorage = newValue
            updateResentDateHeader()
        }
    }

    /// The address in the Sender header.
    ///
    /// The "Sender" field specifies the mailbox of the agent responsible for
    /// the actual transmission of the message. For example, if a secretary were to send
    /// a message for another person, the mailbox of the secretary would appear in the
    /// "Sender" field and the mailbox of the actual author would appear in the "From"
    /// field. If the originator of the message can be indicated by a single mailbox and
    /// the author and transmitter are identical, the "Sender" field should not be used.
    /// Otherwise, both fields should appear.
    public var sender: MailboxAddress? {
        get { senderStorage }
        set {
            senderStorage = newValue
            updateSenderHeader()
        }
    }

    /// The address in the Resent-Sender header.
    ///
    /// The resent sender may differ from the addresses in ``resentFrom`` if
    /// the message was sent by someone on behalf of someone else.
    public var resentSender: MailboxAddress? {
        get { resentSenderStorage }
        set {
            resentSenderStorage = newValue
            updateResentSenderHeader()
        }
    }

    /// The message identifier in the Message-Id header.
    ///
    /// The "Message-Id" field contains a single unique message identifier that refers
    /// to a particular version of a particular message. The uniqueness of the message
    /// identifier is guaranteed by the host that generates it.
    ///
    /// This property returns the message ID without the angle brackets.
    public var messageId: String? {
        get { messageIdStorage }
        set {
            _ = try? setMessageId(newValue)
        }
    }

    /// The message identifier in the Resent-Message-Id header.
    ///
    /// The "Resent-Message-Id" field contains a unique message identifier that refers
    /// to a particular version of a resent message.
    ///
    /// This property returns the message ID without the angle brackets.
    public var resentMessageId: String? {
        get { resentMessageIdStorage }
        set {
            _ = try? setResentMessageId(newValue)
        }
    }

    /// The message identifier in the In-Reply-To header.
    ///
    /// The "In-Reply-To" field contains the message identifier of the message to which
    /// this message is a reply. This is used to establish threading relationships between messages.
    ///
    /// This property returns the message ID without the angle brackets.
    public var inReplyTo: String? {
        get { inReplyToStorage }
        set {
            _ = try? setInReplyTo(newValue)
        }
    }

    /// The MIME version of the message.
    ///
    /// The "MIME-Version" field indicates the version of the MIME protocol used in
    /// constructing the message. Most messages will have a MIME version of "1.0".
    public var mimeVersion: MimeVersion? {
        get { mimeVersionStorage }
        set {
            mimeVersionStorage = newValue
            updateMimeVersionHeader()
        }
    }

    /// The importance of the message.
    ///
    /// The "Importance" header is used to indicate the relative importance of the message.
    public var importance: MessageImportance {
        get { importanceStorage }
        set {
            importanceStorage = newValue
            updateImportanceHeader()
        }
    }

    /// The priority of the message.
    ///
    /// The "Priority" header is used to indicate the relative priority of the message.
    public var priority: MessagePriority {
        get { priorityStorage }
        set {
            priorityStorage = newValue
            updatePriorityHeader()
        }
    }

    /// The X-Priority of the message.
    ///
    /// The "X-Priority" header is a non-standard extension used to indicate message
    /// priority on a scale from 1 (highest) to 5 (lowest).
    public var xPriority: XMessagePriority {
        get { xPriorityStorage }
        set {
            xPriorityStorage = newValue
            updateXPriorityHeader()
        }
    }

    internal init(addDefaults: Bool) {
        self.headers = HeaderList()
        self.from = InternetAddressList()
        self.to = InternetAddressList()
        self.cc = InternetAddressList()
        self.replyTo = InternetAddressList()
        self.bcc = InternetAddressList()
        self.resentFrom = InternetAddressList()
        self.resentReplyTo = InternetAddressList()
        self.resentTo = InternetAddressList()
        self.resentCc = InternetAddressList()
        self.resentBcc = InternetAddressList()
        self.references = MessageIdList()

        configureAddressList(from, id: .from)
        configureAddressList(to, id: .to)
        configureAddressList(cc, id: .cc)
        configureAddressList(replyTo, id: .replyTo)
        configureAddressList(bcc, id: .bcc)
        configureAddressList(resentFrom, id: .resentFrom)
        configureAddressList(resentReplyTo, id: .resentReplyTo)
        configureAddressList(resentTo, id: .resentTo)
        configureAddressList(resentCc, id: .resentCc)
        configureAddressList(resentBcc, id: .resentBcc)

        references.changed = { [weak self] _ in
            self?.updateReferencesHeader()
        }

        headers.changed = { [weak self] action, header in
            self?.headersChanged(action, header: header)
        }

        if addDefaults {
            headers[.from] = ""
            date = DateTimeOffset.now()
            subject = ""
            messageId = MimeUtils.generateMessageId()
        }
    }

    /// Initializes a new instance of ``MimeMessage``.
    ///
    /// Creates a new MIME message with default headers including From, Date, Subject,
    /// and Message-Id.
    public convenience init() {
        self.init(addDefaults: true)
    }

    /// Initializes a new instance of ``MimeMessage`` with the specified arguments.
    ///
    /// - Parameter args: An array of initialization parameters: headers and message parts.
    /// - Throws: ``MimeMessageError/duplicateBody`` if more than one body is specified,
    ///           or ``MimeMessageError/invalidArgument`` if an unknown argument type is provided.
    public convenience init(_ args: Any?...) throws {
        try self.init(args: args)
    }

    /// Initializes a new instance of ``MimeMessage`` with the specified arguments.
    ///
    /// - Parameter args: An array of initialization parameters: headers and message parts.
    /// - Throws: ``MimeMessageError/duplicateBody`` if more than one body is specified,
    ///           or ``MimeMessageError/invalidArgument`` if an unknown argument type is provided.
    public convenience init(args: [Any?]) throws {
        self.init(addDefaults: false)
        var body: MimeEntity?
        for obj in args {
            guard let obj else { continue }
            if let header = obj as? Header {
                if !header.field.hasPrefix("Content-") && !header.field.hasPrefix("content-") {
                    headers.add(header)
                }
                continue
            }
            if let headerList = obj as? [Header] {
                for header in headerList where !header.field.lowercased().hasPrefix("content-") {
                    headers.add(header)
                }
                continue
            }
            if let entity = obj as? MimeEntity {
                if body != nil {
                    throw MimeMessageError.duplicateBody
                }
                body = entity
                continue
            }
            throw MimeMessageError.invalidArgument
        }

        if let body {
            self.body = body
        }

        syncFromHeaders()

        if headers[.from] == nil {
            headers[.from] = ""
        }
        if headers[.date] == nil {
            date = DateTimeOffset.now()
        }
        if headers[.subject] == nil {
            subject = ""
        }
        if headers[.messageId] == nil {
            messageId = MimeUtils.generateMessageId()
        }
    }

    /// Initializes a new instance of ``MimeMessage`` with the specified headers.
    ///
    /// - Parameter headers: A list of initial message headers.
    public convenience init(headers: [Header]) {
        self.init(addDefaults: false)
        for header in headers where !header.field.lowercased().hasPrefix("content-") {
            self.headers.add(header)
        }
        syncFromHeaders()
    }

    /// Initializes a new instance of ``MimeMessage`` with the specified details.
    ///
    /// Creates a new MIME message, specifying details at creation time.
    ///
    /// - Parameters:
    ///   - from: The list of addresses in the From header.
    ///   - to: The list of addresses in the To header.
    ///   - subject: The subject of the message.
    ///   - body: The body of the message.
    public convenience init(from: [InternetAddress], to: [InternetAddress], subject: String, body: MimeEntity) {
        self.init(addDefaults: true)
        self.from.addRange(from)
        self.to.addRange(to)
        self.subject = subject
        self.body = body
    }

    /// Prepares the message for transport using the specified encoding constraints.
    ///
    /// Ensures that the message body is properly encoded according to the specified
    /// constraints, preparing it for transmission over protocols that may have
    /// encoding or line length restrictions.
    ///
    /// - Parameters:
    ///   - constraint: The encoding constraint to apply.
    ///   - maxLineLength: The maximum line length. Defaults to 78 characters.
    /// - Throws: ``MimeMessageError/invalidMaxLineLength`` if the max line length is invalid.
    public func prepare(_ constraint: EncodingConstraint, maxLineLength: Int = FormatOptions.defaultMaxLineLength) throws {
        if maxLineLength < FormatOptions.minimumLineLength || maxLineLength > FormatOptions.maximumLineLength {
            throw MimeMessageError.invalidMaxLineLength
        }

        if let part = body as? MimePart {
            try part.prepare(constraint)
        } else if let messagePart = body as? MessagePart {
            try messagePart.prepare(constraint, maxLineLength: maxLineLength)
        } else if let multipart = body as? Multipart {
            try multipart.prepare(constraint, maxLineLength: maxLineLength)
        }
    }

    /// The text body of the message, if available.
    ///
    /// Traverses the MIME structure to find and return the plain text body of the message.
    /// This is a convenience property that calls ``getTextBody(_:)`` with ``TextFormat/plain``.
    public var textBody: String? {
        getTextBody(.plain)
    }

    /// The HTML body of the message, if available.
    ///
    /// Traverses the MIME structure to find and return the HTML body of the message.
    /// This is a convenience property that calls ``getTextBody(_:)`` with ``TextFormat/html``.
    public var htmlBody: String? {
        getTextBody(.html)
    }

    /// Gets the text body in the specified format.
    ///
    /// Traverses the MIME structure to find and return the body in the specified format.
    ///
    /// - Parameter format: The desired text format.
    /// - Returns: The text body in the specified format, or `nil` if not found.
    public func getTextBody(_ format: TextFormat) -> String? {
        if let multipart = body as? Multipart {
            var text: TextPart? = nil
            if multipart.tryGetValue(format, body: &text), let text {
                return MultipartAlternative.getText(text)
            }
        } else if let text = body as? TextPart, text.isFormat(format), !text.isAttachment {
            return MultipartAlternative.getText(text)
        }
        return nil
    }

    /// All MIME parts in the message body.
    ///
    /// Recursively enumerates all MIME parts contained in the message body,
    /// flattening any multipart structures into a single array.
    public var bodyParts: [MimeEntity] {
        return enumerateMimeParts(body)
    }

    /// All attachments in the message.
    ///
    /// Returns all MIME entities in the message that have a Content-Disposition
    /// header indicating they are attachments.
    public var attachments: [MimeEntity] {
        return enumerateMimeParts(body).filter { $0.contentDisposition?.isAttachment ?? false }
    }

    /// Gets the list of recipients for the message.
    ///
    /// Returns a list of mailbox addresses representing the recipients of the message,
    /// including To, Cc, and Bcc recipients. If resent headers are present, returns
    /// the resent recipients instead.
    ///
    /// - Parameter onlyUnique: If `true`, returns only unique addresses (case-insensitive).
    /// - Returns: An array of mailbox addresses.
    public func getRecipients(_ onlyUnique: Bool = false) -> [MailboxAddress] {
        return getMailboxes(includeSenders: false, onlyUnique: onlyUnique)
    }

    /// Writes the message to the specified stream using default formatting options.
    ///
    /// - Parameter stream: The output stream.
    /// - Throws: An error if writing fails.
    public func writeTo(_ stream: MimeStream) throws {
        try writeTo(.default, stream)
    }

    /// Writes the message to the specified stream using the specified formatting options.
    ///
    /// Serializes the message, including all headers and body content, to the output stream.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - stream: The output stream.
    /// - Throws: An error if writing fails.
    public func writeTo(_ options: FormatOptions, _ stream: MimeStream) throws {
        let combinedHeaders = HeaderList()
        for header in headers {
            combinedHeaders.add(header.copy())
        }
        if let body {
            for header in body.headers where header.field.lowercased().hasPrefix("content-") {
                if header.id != .unknown {
                    if combinedHeaders.contains(header.id) {
                        continue
                    }
                } else if combinedHeaders.contains(field: header.field) {
                    continue
                }
                combinedHeaders.add(header.copy())
            }
        }

        let headersText = combinedHeaders.toString(options, encode: true)
        if !headersText.isEmpty {
            let headerBytes = Array(headersText.utf8)
            try stream.write(headerBytes, offset: 0, count: headerBytes.count)
        }
        let newLineBytes = options.newLineBytes
        try stream.write(newLineBytes, offset: 0, count: newLineBytes.count)
        try stream.write(newLineBytes, offset: 0, count: newLineBytes.count)

        if let body {
            try body.writeBody(options, stream: stream)
        }
    }

    /// Accepts the specified visitor for processing this message.
    ///
    /// Implements the visitor design pattern, allowing external code to process
    /// this message without modifying its class.
    ///
    /// - Parameter visitor: The visitor to accept.
    public func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    internal func hashBody(_ options: FormatOptions, signatureAlgorithm: DkimSignatureAlgorithm, bodyCanonicalization: DkimCanonicalizationAlgorithm, maxLength: Int) throws -> [UInt8] {
        let stream = DkimHashStream(signatureAlgorithm, maxLength: maxLength)
        let filtered = try FilteredStream(stream)
        let dkimFilter: DkimBodyFilter

        switch bodyCanonicalization {
        case .relaxed:
            dkimFilter = DkimRelaxedBodyFilter()
        case .simple:
            dkimFilter = DkimSimpleBodyFilter()
        }

        try filtered.add(options.createNewLineFilter(false))
        try filtered.add(dkimFilter)

        if let body {
            if let multipart = body as? Multipart, let rawBody = multipart.rawBody {
                try filtered.write(rawBody, offset: 0, count: rawBody.count)
            } else {
                body.ensureNewLine = options.ensureNewLine
                try body.writeBody(options, stream: filtered)
                body.ensureNewLine = false
            }
        }

        try filtered.flush()

        if !dkimFilter.lastWasNewLine {
            let newLine = options.newLineBytes
            try stream.write(newLine, offset: 0, count: newLine.count)
        }

        return stream.generateHash()
    }

    /// Loads a MIME message from the specified stream using default parser options.
    ///
    /// - Parameter stream: The stream to load the message from.
    /// - Returns: The parsed MIME message.
    /// - Throws: An error if loading or parsing fails.
    public static func load(_ stream: MimeStream) throws -> MimeMessage {
        let bytes = try readAllBytes(from: stream)
        return try parse(.default, bytes)
    }

    /// Loads a MIME message from the specified stream using the specified parser options.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - stream: The stream to load the message from.
    /// - Returns: The parsed MIME message.
    /// - Throws: An error if loading or parsing fails.
    public static func load(_ options: ParserOptions, _ stream: MimeStream) throws -> MimeMessage {
        let bytes = try readAllBytes(from: stream)
        return try parse(options, bytes)
    }

    private static func parse(_ options: ParserOptions, _ bytes: [UInt8]) throws -> MimeMessage {
        let (headerList, bodyBytes) = parseHeaders(bytes)
        let message = MimeMessage(addDefaults: false)
        for header in headerList {
            message.headers.add(header)
        }

        message.syncFromHeaders()

        if !bodyBytes.isEmpty {
            let entityHeaders = HeaderList()
            for header in headerList where header.field.lowercased().hasPrefix("content-") {
                entityHeaders.add(header.copy())
            }
            message.body = try parseEntity(options, entityHeaders, bodyBytes)
        }

        return message
    }

    internal static func parseEntity(_ options: ParserOptions, _ bytes: [UInt8], depth: Int = 0) throws -> MimeEntity? {
        try parseEntity(options, ArraySlice(bytes), depth: depth)
    }

    internal static func parseEntity(_ options: ParserOptions, _ bytes: ArraySlice<UInt8>, depth: Int = 0) throws -> MimeEntity? {
        let (headers, bodyBytes) = parseHeaders(bytes)
        if headers.isEmpty && bodyBytes.isEmpty {
            return nil
        }
        return try parseEntity(options, headers, bodyBytes, depth: depth)
    }

    internal static func parseEntity(_ options: ParserOptions, _ headers: HeaderList, _ bodyBytes: ArraySlice<UInt8>, depth: Int = 0) throws -> MimeEntity? {
        guard depth < options.maxMimeDepth else { throw ParseException("MIME nesting limit exceeded.", tokenIndex: 0, errorIndex: 0) }
        func removeAutoContentTypeHeader(from entity: MimeEntity) {
            for index in 0..<entity.headers.count {
                let header = entity.headers[index]
                if header.id == .contentType || header.field.caseInsensitiveCompare("content-type") == .orderedSame {
                    entity.headers.remove(at: index)
                    break
                }
            }
        }

        func applyHeaders(_ entity: MimeEntity, removeAutoContentType: Bool = true) {
            for header in headers {
                entity.headers.add(header)
            }
            if removeAutoContentType {
                removeAutoContentTypeHeader(from: entity)
            }
        }

        var contentType: ContentType? = nil
        if let header = headers.tryGetHeader(.contentType) {
            let value = header.value
            if let parsed = try? ContentType(parsing: value) {
                contentType = parsed
            } else {
                let fallback = try ContentType("application", "octet-stream")
                let bytes = Array(value.utf8)
                if let semiIndex = bytes.firstIndex(of: UInt8(ascii: ";")) {
                    var index = semiIndex + 1
                    var params: ParameterList?
                    _ = try? ParameterList.tryParse(options, bytes, index: &index, endIndex: bytes.count, throwOnError: false, paramList: &params)
                    if let params {
                        fallback.parameters = params
                    }
                }
                contentType = fallback
            }
        }
        if contentType == nil {
            contentType = try ContentType("text", "plain")
        }

        let mediaType = contentType?.mediaType.lowercased() ?? ""
        let mediaSubtype = contentType?.mediaSubtype.lowercased() ?? ""
        let customEntity = contentType.flatMap { options.makeEntity(for: $0) }

        let entity: MimeEntity
        switch (mediaType, mediaSubtype) {
        case ("multipart", _):
            let subtype = mediaSubtype.isEmpty ? "mixed" : mediaSubtype
            let multipart: Multipart
            if let custom = customEntity as? Multipart {
                multipart = custom
            } else {
                multipart = try createMultipart(subtype: subtype)
            }
            if let contentType {
                multipart.contentType = contentType
            }
            applyHeaders(multipart)
            if let boundary = multipart.contentType.boundary, !boundary.isEmpty, !bodyBytes.isEmpty {
                // splitMultipartBody currently expects [UInt8], we might need to update it or copy here for now if heavy refactor is risky
                // For now, let's copy only when needed by this specific method
                let split = splitMultipartBody(Array(bodyBytes), boundary: boundary)
                if let preamble = split.preamble {
                    multipart.preamble = preamble
                }
                if let epilogue = split.epilogue {
                    multipart.epilogue = epilogue
                }
                for partBytes in split.parts {
                    if let child = try parseEntity(options, partBytes, depth: depth + 1) {
                        try multipart.add(child)
                    }
                }
            } else if !bodyBytes.isEmpty {
                if let preamble = String(data: Data(bodyBytes), encoding: .isoLatin1) {
                    multipart.preamble = preamble
                }
            }
            if !bodyBytes.isEmpty {
                multipart.rawBody = Array(bodyBytes)
            }
            entity = multipart
        case ("text", "rfc822-headers"), ("message", "global-headers"):
            let part = (customEntity as? TextRfc822Headers) ?? TextRfc822Headers()
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let (messageHeaders, _) = parseHeaders(bodyBytes)
                let message = MimeMessage(addDefaults: false)
                for header in messageHeaders {
                    message.headers.add(header)
                }
                part.message = message
            }
            entity = part
        case ("message", "delivery-status"):
            let resolvedContentType: ContentType
            if let contentType {
                resolvedContentType = contentType
            } else {
                resolvedContentType = try ContentType("message", "delivery-status")
            }
            let part = (customEntity as? MessageDeliveryStatus) ?? MessageDeliveryStatus(resolvedContentType)
            if let contentType {
                part.contentType = contentType
            }
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("message", "disposition-notification"):
            let resolvedContentType: ContentType
            if let contentType {
                resolvedContentType = contentType
            } else {
                resolvedContentType = try ContentType("message", "disposition-notification")
            }
            let part = (customEntity as? MessageDispositionNotification) ?? MessageDispositionNotification(resolvedContentType)
            if let contentType {
                part.contentType = contentType
            }
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("message", "feedback-report"):
            let resolvedContentType: ContentType
            if let contentType {
                resolvedContentType = contentType
            } else {
                resolvedContentType = try ContentType("message", "feedback-report")
            }
            let part = (customEntity as? MessageFeedbackReport) ?? MessageFeedbackReport(resolvedContentType)
            if let contentType {
                part.contentType = contentType
            }
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("message", "partial"):
            let resolvedContentType: ContentType
            if let contentType {
                resolvedContentType = contentType
            } else {
                resolvedContentType = try ContentType("message", "partial")
            }
            let part = (customEntity as? MessagePartial) ?? MessagePartial(resolvedContentType)
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("message", _):
            let part = (customEntity as? MessagePart) ?? MessagePart(mediaSubtype.isEmpty ? "rfc822" : mediaSubtype)
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                var childOptions = options
                childOptions.maxMimeDepth = options.maxMimeDepth - depth - 1
                part.message = try parse(childOptions, Array(bodyBytes))
            }
            entity = part
        case ("application", "pkcs7-signature"), ("application", "x-pkcs7-signature"):
            let part = (customEntity as? ApplicationPkcs7Signature) ?? ApplicationPkcs7Signature()
            if let contentType {
                part.contentType = contentType
            }
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("application", "pkcs7-mime"), ("application", "x-pkcs7-mime"):
            let part = (customEntity as? ApplicationPkcs7Mime) ?? ApplicationPkcs7Mime()
            if let contentType {
                part.contentType = contentType
            }
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("application", "vnd.ms-tnef"), ("application", "ms-tnef"):
            let resolvedContentType: ContentType
            if let contentType {
                resolvedContentType = contentType
            } else {
                resolvedContentType = try ContentType("application", "vnd.ms-tnef")
            }
            let part = (customEntity as? TnefPart) ?? TnefPart(resolvedContentType)
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        case ("text", _), ("application", "rtf"):
            let subtype = mediaSubtype.isEmpty ? "plain" : mediaSubtype
            let part = (customEntity as? TextPart) ?? TextPart(subtype)
            if let contentType {
                part.contentType = contentType
            }
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        default:
            let fallback = try ContentType("application", "octet-stream")
            let part = (customEntity as? MimePart) ?? MimePart(contentType ?? fallback)
            applyHeaders(part)
            if !bodyBytes.isEmpty {
                let encoding = part.contentTransferEncoding
                part.content = MimeContent(MemoryStream(Array(bodyBytes), writable: false), encoding: encoding)
            }
            entity = part
        }

        return entity
    }

    internal static func parseEntity(_ options: ParserOptions, _ headers: HeaderList, _ bodyBytes: [UInt8]) throws -> MimeEntity? {
        try parseEntity(options, headers, ArraySlice(bodyBytes))
    }

    internal static func parseHeaders(_ bytes: [UInt8]) -> (HeaderList, [UInt8]) {
        let (headers, bodySlice) = parseHeaders(ArraySlice(bytes))
        return (headers, Array(bodySlice))
    }

    internal static func parseHeaders(_ bytes: ArraySlice<UInt8>) -> (HeaderList, ArraySlice<UInt8>) {
        let separator = findHeaderBodySeparator(bytes)
        let headerList = HeaderList()
        var bodyBytes: ArraySlice<UInt8> = []

        var headerLimit = bytes.endIndex
        if let separator {
            let lineBreakLength = (bytes[separator.headerEnd] == 0x0D) ? 2 : 1
            headerLimit = min(bytes.endIndex, separator.headerEnd + lineBreakLength)
            bodyBytes = bytes[separator.bodyStart..<bytes.endIndex]
        }

        var currentFieldBytes: [UInt8]? = nil
        var currentFieldNameLength = 0
        var currentRawValue: [UInt8] = []

        func finalizeHeader() {
            guard let fieldBytes = currentFieldBytes else { return }
            let header = Header(.default, fieldBytes: fieldBytes, fieldNameLength: currentFieldNameLength, rawValue: currentRawValue)
            headerList.add(header)
            currentFieldBytes = nil
            currentFieldNameLength = 0
            currentRawValue = []
        }

        var index = bytes.startIndex
        while index < headerLimit {
            let lineStart = index
            while index < headerLimit && bytes[index] != 0x0A {
                index += 1
            }
            let lineEnd = index
            var hasLineFeed = false
            if index < headerLimit && bytes[index] == 0x0A {
                hasLineFeed = true
                index += 1
            }

            let lineBytes = bytes[lineStart..<lineEnd]
            var lineBreak: [UInt8] = []
            var lineContent = Array(lineBytes)

            if hasLineFeed {
                if lineContent.last == 0x0D {
                    lineContent.removeLast()
                    lineBreak = [0x0D, 0x0A]
                } else {
                    lineBreak = [0x0A]
                }
            }

            if lineContent.isEmpty {
                finalizeHeader()
                break
            }

            if lineContent.first == 0x20 || lineContent.first == 0x09 {
                if currentFieldBytes != nil {
                    currentRawValue.append(contentsOf: lineContent)
                    currentRawValue.append(contentsOf: lineBreak)
                }
                continue
            }

            finalizeHeader()

            if let colonIndex = lineContent.firstIndex(of: UInt8(ascii: ":")) {
                let fieldBytes = Array(lineContent[0..<colonIndex])
                let valueStart = lineContent.index(after: colonIndex)
                let rawValue = Array(lineContent[valueStart..<lineContent.count]) + lineBreak
                currentFieldBytes = fieldBytes
                currentFieldNameLength = fieldBytes.count
                currentRawValue = rawValue
            } else {
                let rawField = lineContent + lineBreak
                let header = Header(.default, fieldBytes: rawField, fieldNameLength: rawField.count, rawValue: [])
                header.isInvalid = true
                headerList.add(header)
            }
        }

        finalizeHeader()

        if separator == nil && headerList.isEmpty {
            bodyBytes = bytes
        }

        return (headerList, bodyBytes)
    }

    private static func createMultipart(subtype: String) throws -> Multipart {
        switch subtype.lowercased() {
        case "alternative":
            return MultipartAlternative()
        case "related":
            return MultipartRelated()
        case "report":
            return MultipartReport()
        case "signed":
            if #available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *) {
                return MultipartSigned()
            } else {
                return try Multipart(subtype)
            }
        default:
            return try Multipart(subtype)
        }
    }

    // Zhichu patch: split at byte offsets. A Latin-1 -> UTF-8 roundtrip corrupts 8-bit bodies and binary attachments.
    private static func splitMultipartBody(_ bytes: [UInt8], boundary: String) -> (preamble: String?, parts: [[UInt8]], epilogue: String?) {
        let marker = Array(("--" + boundary).utf8)
        var parts: [[UInt8]] = []
        var cursor = 0, partStart: Int?, preambleEnd = 0, epilogueStart: Int?
        func endingBefore(_ index: Int) -> Int {
            var end = index
            if end > 0, bytes[end - 1] == 10 { end -= 1 }
            if end > 0, bytes[end - 1] == 13 { end -= 1 }
            return end
        }
        while cursor < bytes.count {
            let start = cursor
            while cursor < bytes.count, bytes[cursor] != 10 { cursor += 1 }
            var end = cursor
            if end > start, bytes[end - 1] == 13 { end -= 1 }
            if cursor < bytes.count { cursor += 1 }
            let line = bytes[start..<end]
            guard line.starts(with: marker) else { continue }
            let suffix = line.dropFirst(marker.count)
            let closing = suffix.starts(with: [45, 45])
            let trailing = closing ? suffix.dropFirst(2) : suffix
            guard trailing.allSatisfy({ $0 == 32 || $0 == 9 }) else { continue }
            if let partStart { parts.append(Array(bytes[partStart..<max(partStart, endingBefore(start))])) }
            else { preambleEnd = endingBefore(start) }
            if closing { epilogueStart = cursor; partStart = nil; break }
            partStart = cursor
        }
        if let partStart { parts.append(Array(bytes[partStart..<bytes.count])) }
        let preamble = preambleEnd > 0 ? String(bytes: bytes[..<preambleEnd], encoding: .isoLatin1) : nil
        let epilogue = epilogueStart.flatMap { String(bytes: bytes[$0...], encoding: .isoLatin1) }
        return (preamble, parts, epilogue)
    }

    private static func decodeContentBytes(_ bytes: [UInt8], encoding: ContentEncoding) -> [UInt8] {
        switch encoding {
        case .base64, .quotedPrintable, .uuEncode:
            let source = MemoryStream(bytes, writable: false)
            let filtered = try? FilteredStream(source)
            let filter = DecoderFilter.create(encoding)
            _ = try? filtered?.add(filter)
            var buffer = [UInt8](repeating: 0, count: 4096)
            var output: [UInt8] = []
            while true {
                let read = (try? filtered?.read(&buffer, offset: 0, count: buffer.count)) ?? 0
                if read == 0 {
                    break
                }
                output.append(contentsOf: buffer[0..<read])
            }
            return output
        default:
            return bytes
        }
    }

    private func enumerateMimeParts(_ entity: MimeEntity?) -> [MimeEntity] {
        guard let entity else { return [] }
        if let multipart = entity as? Multipart {
            var parts: [MimeEntity] = []
            for part in multipart {
                parts.append(contentsOf: enumerateMimeParts(part))
            }
            return parts
        }
        return [entity]
    }

    private func getMailboxes(includeSenders: Bool, onlyUnique: Bool) -> [MailboxAddress] {
        var recipients: [MailboxAddress] = []
        var unique: Set<String>? = nil
        if onlyUnique {
            unique = Set<String>()
        }

        func addMailboxes(_ mailboxes: [MailboxAddress]) {
            for mailbox in mailboxes {
                if var uniqueSet = unique {
                    let key = mailbox.address.lowercased()
                    if uniqueSet.contains(key) {
                        continue
                    }
                    uniqueSet.insert(key)
                    unique = uniqueSet
                }
                recipients.append(mailbox)
            }
        }

        if resentSenderStorage != nil || resentFrom.count > 0 {
            if includeSenders {
                if let resentSenderStorage {
                    addMailboxes([resentSenderStorage])
                }
                addMailboxes(resentFrom.mailboxes)
            }
            addMailboxes(resentTo.mailboxes)
            addMailboxes(resentCc.mailboxes)
            addMailboxes(resentBcc.mailboxes)
        } else {
            if includeSenders {
                if let senderStorage {
                    addMailboxes([senderStorage])
                }
                addMailboxes(from.mailboxes)
            }
            addMailboxes(to.mailboxes)
            addMailboxes(cc.mailboxes)
            addMailboxes(bcc.mailboxes)
        }

        return recipients
    }

    private static func findHeaderBodySeparator(_ bytes: ArraySlice<UInt8>) -> (headerEnd: Int, bodyStart: Int)? {
        if bytes.count < 2 {
            return nil
        }
        let startIndex = bytes.startIndex
        if bytes[startIndex] == 0x0D, bytes[startIndex + 1] == 0x0A {
            return (startIndex, startIndex + 2)
        }
        if bytes[startIndex] == 0x0A {
            return (startIndex, startIndex + 1)
        }
        var index = startIndex
        let endIndex = bytes.endIndex
        while index + 1 < endIndex {
            if bytes[index] == 0x0D, bytes[index + 1] == 0x0A {
                if index + 3 < endIndex,
                   bytes[index + 2] == 0x0D,
                   bytes[index + 3] == 0x0A {
                    return (index, index + 4)
                }
            }
            if bytes[index] == 0x0A, bytes[index + 1] == 0x0A {
                return (index, index + 2)
            }
            index += 1
        }
        return nil
    }

    private static func findHeaderBodySeparator(_ bytes: [UInt8]) -> (headerEnd: Int, bodyStart: Int)? {
        findHeaderBodySeparator(ArraySlice(bytes))
    }

    private static func readAllBytes(from stream: MimeStream) throws -> [UInt8] {
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

    private func configureAddressList(_ list: InternetAddressList, id: HeaderId) {
        list.changed = { [weak self, weak list] _ in
            guard let list else { return }
            self?.updateAddressHeader(id, list: list)
        }
    }

    private func updateAddressHeader(_ id: HeaderId, list: InternetAddressList?) {
        guard let list else { return }
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if list.count == 0 {
            headers.removeAll(id)
        } else {
            headers[id] = list.toString(.default, encode: true)
        }
        isUpdatingHeaders = false
    }

    private func updateSubjectHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let subjectStorage {
            headers[.subject] = subjectStorage
        } else {
            headers.removeAll(.subject)
        }
        isUpdatingHeaders = false
    }

    private func updateDateHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let dateStorage {
            headers[.date] = DateUtils.formatDate(dateStorage)
        } else {
            headers.removeAll(.date)
        }
        isUpdatingHeaders = false
    }

    private func updateResentDateHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let resentDateStorage {
            headers[.resentDate] = DateUtils.formatDate(resentDateStorage)
        } else {
            headers.removeAll(.resentDate)
        }
        isUpdatingHeaders = false
    }

    private func updateSenderHeader() {
        updateMailboxHeader(.sender, mailbox: senderStorage)
    }

    private func updateResentSenderHeader() {
        updateMailboxHeader(.resentSender, mailbox: resentSenderStorage)
    }

    private func updateMimeVersionHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let mimeVersionStorage {
            headers[.mimeVersion] = mimeVersionStorage.description
        } else {
            headers.removeAll(.mimeVersion)
        }
        isUpdatingHeaders = false
    }

    private func updateImportanceHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        let value: String
        switch importanceStorage {
        case .high:
            value = "high"
        case .low:
            value = "low"
        case .normal:
            value = "normal"
        }
        headers[.importance] = value
        isUpdatingHeaders = false
    }

    private func updatePriorityHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        let value: String
        switch priorityStorage {
        case .nonUrgent:
            value = "non-urgent"
        case .normal:
            value = "normal"
        case .urgent:
            value = "urgent"
        }
        headers[.priority] = value
        isUpdatingHeaders = false
    }

    private func updateXPriorityHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        let value: String
        switch xPriorityStorage {
        case .highest:
            value = "1 (Highest)"
        case .high:
            value = "2 (High)"
        case .normal:
            value = "3 (Normal)"
        case .low:
            value = "4 (Low)"
        case .lowest:
            value = "5 (Lowest)"
        }
        headers[.xPriority] = value
        isUpdatingHeaders = false
    }

    private func updateReferencesHeader() {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if references.count == 0 {
            headers.removeAll(.references)
        } else {
            headers[.references] = references.toString()
        }
        isUpdatingHeaders = false
    }

    private func updateMailboxHeader(_ id: HeaderId, mailbox: MailboxAddress?) {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let mailbox {
            let list = InternetAddressList([mailbox])
            headers[id] = list.toString(.default, encode: true)
        } else {
            headers.removeAll(id)
        }
        isUpdatingHeaders = false
    }

    /// Sets the Message-Id header value.
    ///
    /// - Parameter value: The message ID value, or `nil` to remove the header.
    /// - Throws: ``MimeMessageError/invalidMessageId`` if the value is not a valid message ID.
    public func setMessageId(_ value: String?) throws {
        if let value {
            let msgid = try parseMessageIdValue(value, error: .invalidMessageId)
            messageIdStorage = msgid
            updateMessageIdHeader(.messageId, value: msgid)
        } else {
            messageIdStorage = nil
            updateMessageIdHeader(.messageId, value: nil)
        }
    }

    /// Sets the Resent-Message-Id header value.
    ///
    /// - Parameter value: The resent message ID value, or `nil` to remove the header.
    /// - Throws: ``MimeMessageError/invalidResentMessageId`` if the value is not a valid message ID.
    public func setResentMessageId(_ value: String?) throws {
        if let value {
            let msgid = try parseMessageIdValue(value, error: .invalidResentMessageId)
            resentMessageIdStorage = msgid
            updateMessageIdHeader(.resentMessageId, value: msgid)
        } else {
            resentMessageIdStorage = nil
            updateMessageIdHeader(.resentMessageId, value: nil)
        }
    }

    /// Sets the In-Reply-To header value.
    ///
    /// - Parameter value: The In-Reply-To message ID value, or `nil` to remove the header.
    /// - Throws: ``MimeMessageError/invalidInReplyTo`` if the value is not a valid message ID.
    public func setInReplyTo(_ value: String?) throws {
        if let value {
            let msgid = try parseMessageIdValue(value, error: .invalidInReplyTo)
            inReplyToStorage = msgid
            updateMessageIdHeader(.inReplyTo, value: msgid)
        } else {
            inReplyToStorage = nil
            updateMessageIdHeader(.inReplyTo, value: nil)
        }
    }

    private func updateMessageIdHeader(_ id: HeaderId, value: String?) {
        guard !isUpdatingHeaders else { return }
        isUpdatingHeaders = true
        if let value {
            headers[id] = "<\(value)>"
        } else {
            headers.removeAll(id)
        }
        isUpdatingHeaders = false
    }

    private func parseMessageIdValue(_ value: String, error: MimeMessageError) throws -> String {
        let buffer = Array(value.utf8)
        var index = 0
        var msgid: String? = nil
        let parsed = (try? ParseUtils.tryParseMsgId(buffer, index: &index, endIndex: buffer.count, requireAngleAddr: false, throwOnError: false, msgid: &msgid)) ?? false
        guard parsed, let msgid else {
            throw error
        }
        return msgid
    }

    private func headersChanged(_ action: HeaderListChangedAction, header: Header?) {
        guard !isUpdatingHeaders else { return }
        switch action {
        case .cleared, .added, .changed, .removed:
            syncFromHeaders()
        }
    }

    private func updateAddressList(_ list: InternetAddressList, addresses: [InternetAddress]) {
        let saved = list.changed
        list.changed = nil
        list.clear()
        for address in addresses {
            list.add(address)
        }
        list.changed = saved
    }

    private func addressesFromHeaders(_ id: HeaderId) -> [InternetAddress] {
        var addresses: [InternetAddress] = []
        for header in headers where header.id == id {
            if let list = try? InternetAddressList(parsing: header.rawValue, options: headers.options) {
                addresses.append(contentsOf: list)
            }
        }
        return addresses
    }

    private func mailboxFromHeader(_ id: HeaderId) -> MailboxAddress? {
        guard let header = headers.tryGetHeader(id) else { return nil }
        return try? MailboxAddress(parsing: header.rawValue, options: headers.options)
    }

    private func dateFromHeader(_ id: HeaderId) -> DateTimeOffset? {
        guard let header = headers.tryGetHeader(id) else { return nil }
        var parsed: DateTimeOffset? = nil
        if DateUtils.tryParse(header.rawValue, date: &parsed) {
            return parsed
        }
        return nil
    }

    private func messageIdFromHeader(_ id: HeaderId) -> String? {
        guard let header = headers.tryGetHeader(id) else { return nil }
        return MimeUtils.parseMessageId(header.rawValue, startIndex: 0, length: header.rawValue.count)
    }

    private func inReplyToFromHeader() -> String? {
        guard let header = headers.tryGetHeader(.inReplyTo) else { return nil }
        return MimeUtils.enumerateReferences(header.rawValue, startIndex: 0, length: header.rawValue.count).first
    }

    private func mimeVersionFromHeader() -> MimeVersion? {
        guard let header = headers.tryGetHeader(.mimeVersion) else { return nil }
        return MimeUtils.tryParseVersion(header.rawValue, startIndex: 0, length: header.rawValue.count)
    }

    private func importanceFromHeader() -> MessageImportance {
        let value = headers[.importance]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value {
        case "high":
            return .high
        case "low":
            return .low
        default:
            return .normal
        }
    }

    private func priorityFromHeader() -> MessagePriority {
        let value = headers[.priority]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value {
        case "non-urgent":
            return .nonUrgent
        case "urgent":
            return .urgent
        default:
            return .normal
        }
    }

    private func xPriorityFromHeader() -> XMessagePriority {
        guard let header = headers.tryGetHeader(.xPriority) else { return .normal }
        var index = 0
        let rawValue = header.rawValue
        _ = ParseUtils.skipWhiteSpace(rawValue, index: &index, endIndex: rawValue.count)
        var number = 0
        if ParseUtils.tryParseInt32(rawValue, index: &index, endIndex: rawValue.count, value: &number) {
            let clamped = Swift.min(Swift.max(number, 1), 5)
            return XMessagePriority(rawValue: clamped) ?? .normal
        }
        return .normal
    }

    private func updateReferencesFromHeaders() {
        let saved = references.changed
        references.changed = nil
        references.clear()
        if let header = headers.tryGetHeader(.references) {
            for msgid in MimeUtils.enumerateReferences(header.rawValue, startIndex: 0, length: header.rawValue.count) {
                references.add(msgid)
            }
        }
        references.changed = saved
    }

    private func syncFromHeaders() {
        updateAddressList(from, addresses: addressesFromHeaders(.from))
        updateAddressList(to, addresses: addressesFromHeaders(.to))
        updateAddressList(cc, addresses: addressesFromHeaders(.cc))
        updateAddressList(replyTo, addresses: addressesFromHeaders(.replyTo))
        updateAddressList(bcc, addresses: addressesFromHeaders(.bcc))
        updateAddressList(resentFrom, addresses: addressesFromHeaders(.resentFrom))
        updateAddressList(resentReplyTo, addresses: addressesFromHeaders(.resentReplyTo))
        updateAddressList(resentTo, addresses: addressesFromHeaders(.resentTo))
        updateAddressList(resentCc, addresses: addressesFromHeaders(.resentCc))
        updateAddressList(resentBcc, addresses: addressesFromHeaders(.resentBcc))
        senderStorage = mailboxFromHeader(.sender)
        resentSenderStorage = mailboxFromHeader(.resentSender)
        subjectStorage = headers[.subject]
        dateStorage = dateFromHeader(.date)
        resentDateStorage = dateFromHeader(.resentDate)
        messageIdStorage = messageIdFromHeader(.messageId)
        resentMessageIdStorage = messageIdFromHeader(.resentMessageId)
        inReplyToStorage = inReplyToFromHeader()
        mimeVersionStorage = mimeVersionFromHeader()
        importanceStorage = importanceFromHeader()
        priorityStorage = priorityFromHeader()
        xPriorityStorage = xPriorityFromHeader()
        updateReferencesFromHeaders()
    }
}
