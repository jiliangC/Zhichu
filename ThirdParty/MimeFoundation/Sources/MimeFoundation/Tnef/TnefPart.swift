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
// TnefPart.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A MIME part containing Microsoft TNEF data.
///
/// Represents an application/ms-tnef or application/vnd.ms-tnef part.
///
/// TNEF (Transport Neutral Encapsulation Format) attachments are most often
/// sent by Microsoft Outlook clients.
open class TnefPart: MimePart {
    /// Initialize a new instance of the ``TnefPart`` class.
    ///
    /// Creates a new ``TnefPart`` with a Content-Type of application/vnd.ms-tnef
    /// and a Content-Disposition value of "attachment" and a filename parameter with a
    /// value of "winmail.dat".
    public init() {
        let contentType = try! ContentType("application", "vnd.ms-tnef")
        super.init(contentType)
        fileName = "winmail.dat"
    }

    /// Initialize a new instance of the ``TnefPart`` class.
    ///
    /// This initializer is used by ``MimeParser``.
    ///
    /// - Parameter contentType: The content type of the TNEF part.
    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    /// Dispatches to the specific visit method for this MIME entity.
    ///
    /// This default implementation for ``TnefPart`` nodes calls
    /// ``MimeVisitor/visit(_:)-tnef``. Override this method to call into a more specific
    /// method on a derived visitor class of the ``MimeVisitor`` class. However, it should
    /// still support unknown visitors by calling ``MimeVisitor/visit(_:)-tnef``.
    ///
    /// - Parameter visitor: The visitor.
    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    /// Convert the TNEF content into a ``MimeMessage``.
    ///
    /// TNEF data often contains properties that map to ``MimeMessage`` headers.
    /// TNEF data also often contains file attachments which will be mapped to MIME parts.
    ///
    /// - Returns: A message representing the TNEF data in MIME format.
    /// - Throws: ``StreamError/notSupported`` if the ``MimePart/content`` property is `nil`.
    public func convertToMessage() throws -> MimeMessage {
        guard let content = content else {
            throw StreamError.notSupported // Cannot parse null TNEF data
        }

        var codepage = 0
        if let charset = contentType.charset, !charset.isEmpty {
            codepage = CharsetUtils.getCodePage(charset)
            if codepage == -1 { codepage = 0 }
        }

        let reader = TnefReader(inputStream: try content.open(), defaultMessageCodepage: codepage, complianceMode: .loose)

        return try TnefPart.extractTnefMessage(reader)
    }

    private static func extractTnefMessage(_ reader: TnefReader) throws -> MimeMessage {
        let message = MimeMessage()
        // Remove auto-generated date and messageId - these should come from TNEF properties
        message.headers.removeAll(.date)
        message.headers.removeAll(.messageId)
        let alternatives = MultipartAlternative()
        var body: MimeEntity? = nil

        while try reader.readNextAttribute() {
            if reader.attributeLevel == .attachment {
                break
            }

            let prop = reader.tnefPropertyReader!

            switch reader.attributeTag {
            case .recipientTable:
                try extractRecipientTable(reader, message)
            case .mapiProperties:
                try extractMapiProperties(reader, message, alternatives)
            case .dateSent:
                message.date = try prop.readValueAsDateTime()
            case .body:
                let text = try prop.readValueAsString()
                body = TextPart("plain", text)
            default:
                break
            }
        }

        if let b = body {
            if alternatives.count > 0 {
                try alternatives.add(b)
                body = alternatives
            }
        } else if alternatives.count > 0 {
            if alternatives.count == 1 {
                body = alternatives[0]
            } else {
                body = alternatives
            }
        }

        if reader.attributeLevel == .attachment {
            let attachments = try Multipart("mixed")
            if let b = body {
                try attachments.add(b)
            }
            message.body = attachments
            try extractAttachments(reader, attachments)
        } else {
            message.body = body
        }

        return message
    }

    private static func extractRecipientTable(_ reader: TnefReader, _ message: MimeMessage) throws {
        let prop = reader.tnefPropertyReader!

        while try prop.readNextRow() {
            var transmitableDisplayName: String? = nil
            var recipientDisplayName: String? = nil
            var displayName = ""
            var list: InternetAddressList? = nil
            var addr: String? = nil

            while try prop.readNextProperty() {
                switch prop.propertyTag.id {
                case .recipientType:
                    let recipientType = try prop.readValueAsInt32()
                    switch recipientType {
                    case 1: list = message.to
                    case 2: list = message.cc
                    case 3: list = message.bcc
                    default: break
                    }
                case .transmitableDisplayName:
                    transmitableDisplayName = try prop.readValueAsString()
                case .recipientDisplayName:
                    recipientDisplayName = try prop.readValueAsString()
                case .displayName:
                    displayName = try prop.readValueAsString()
                case .emailAddress:
                    if addr?.isEmpty ?? true {
                        addr = try prop.readValueAsString()
                    }
                case .smtpAddress:
                    addr = try prop.readValueAsString()
                default:
                    break
                }
            }

            if let list = list, let addr = addr, !addr.isEmpty {
                let name = recipientDisplayName ?? transmitableDisplayName ?? displayName
                list.add(MailboxAddress(name: name, address: addr))
            }
        }
    }

    private struct TnefEmailAddress {
        var addrType = "SMTP"
        var searchKey: String?
        var name: String?
        var addr: String?

        private var canUseSearchKey: Bool {
            guard let key = searchKey else { return false }
            return key.uppercased().hasPrefix("SMTP:") && key.hasPrefix(addrType + ":")
        }

        func tryGetMailboxAddress() -> MailboxAddress? {
            var address = addr
            if address?.isEmpty ?? true, canUseSearchKey, let key = searchKey {
                address = String(key.dropFirst(addrType.count + 1))
            }

            guard let address = address, !address.isEmpty else { return nil }

            // Try to parse the address properly
            if let mailbox = try? MailboxAddress(parsing: address) {
                if let n = name, !n.isEmpty {
                    return MailboxAddress(name: n, address: mailbox.address)
                }
                return mailbox
            }

            return MailboxAddress(name: name ?? "", address: address)
        }
    }

    private static func isStringProperty(_ prop: TnefPropertyReader) -> Bool {
        let type = prop.propertyTag.type
        return type == .string8 || type == .unicode || type == .binary
    }

    private static func getHtmlBody(_ prop: TnefPropertyReader, _ codepage: Int) throws -> (text: String, encoding: String.Encoding) {
        let rawValue = try prop.readValueAsBytes()
        var rawLength = rawValue.count

        // Trim trailing nulls
        while rawLength > 0 && rawValue[rawLength - 1] == 0 {
            rawLength -= 1
        }

        if rawLength == 0 {
            return ("", .utf8)
        }

        // Try and extract the charset from the HTML meta Content-Type value.
        // First decode as Latin1 to parse the HTML structure
        guard let htmlText = String(data: Data(rawValue[0..<rawLength]), encoding: .isoLatin1) else {
            let encoding = CharsetUtils.getEncoding(codepage: codepage) ?? .isoLatin1
            let text = String(data: Data(rawValue[0..<rawLength]), encoding: encoding) ?? ""
            return (text, encoding)
        }

        let reader = StringReader(htmlText)
        let tokenizer = HtmlTokenizer(reader)

        while let token = tokenizer.readNextToken() {
            guard token.kind == HtmlTokenKind.tag else { continue }
            guard let tag = token as? HtmlTagToken else { continue }

            // Stop at body or end of head
            if tag.id == HtmlTagId.body || (tag.id == HtmlTagId.head && tag.isEndTag) {
                break
            }

            // Look for <meta http-equiv="Content-Type" content="...">
            if tag.id != HtmlTagId.meta || tag.isEndTag {
                continue
            }

            var httpEquiv: String?
            var content: String?

            for attr in tag.attributes {
                let attrName = attr.name.lowercased()
                if attrName == "http-equiv", httpEquiv == nil {
                    httpEquiv = attr.value
                } else if attrName == "content", content == nil {
                    content = attr.value
                } else if attrName == "charset" {
                    // <meta charset="...">
                    if let charsetValue = attr.value, !charsetValue.isEmpty {
                        if let encoding = CharsetUtils.getEncoding(charsetValue) {
                            if let decoded = String(data: Data(rawValue[0..<rawLength]), encoding: encoding) {
                                return (decoded, encoding)
                            }
                        }
                    }
                }
            }

            guard let httpEquiv = httpEquiv, let content = content else { continue }
            guard httpEquiv.caseInsensitiveCompare("Content-Type") == .orderedSame else { continue }

            // Parse the Content-Type to extract charset
            guard let ct = try? ContentType(parsing: content), let charset = ct.charset, !charset.isEmpty else {
                break
            }

            // Try to decode with this charset
            if let encoding = CharsetUtils.getEncoding(charset) {
                if let decoded = String(data: Data(rawValue[0..<rawLength]), encoding: encoding) {
                    return (decoded, encoding)
                }
            }
            break
        }

        // Fall back to the TNEF message codepage
        let encoding = CharsetUtils.getEncoding(codepage: codepage) ?? .isoLatin1
        let text = String(data: Data(rawValue[0..<rawLength]), encoding: encoding) ?? ""
        return (text, encoding)
    }

    private static func extractMapiProperties(_ reader: TnefReader, _ message: MimeMessage, _ alternatives: MultipartAlternative) throws {
        let prop = reader.tnefPropertyReader!
        var sender = TnefEmailAddress()
        var recipient = TnefEmailAddress()
        var normalizedSubject: String? = nil
        var subjectPrefix: String? = nil
        var msgidSet = false

        while try prop.readNextProperty() {
            switch prop.propertyTag.id {
            case .internetMessageId:
                if isStringProperty(prop) {
                    message.messageId = try prop.readValueAsString()
                    msgidSet = true
                }
            case .tnefCorrelationKey:
                // According to MSDN, PidTagTnefCorrelationKey is a unique key that is
                // meant to be used to tie the TNEF attachment to the encapsulating
                // message. It can be a string or a binary blob. It seems that most
                // implementations use the Message-Id string, so if this property
                // value looks like a Message-Id, then use it as one (unless we get a
                // InternetMessageId property, in which case we use that instead.
                if isStringProperty(prop) && !msgidSet {
                    let value = try prop.readValueAsString()
                    // Check if it looks like a message-id (contains @ and is reasonably formatted)
                    if value.count > 5 && value.contains("@") {
                        if value.first == "<" && value.last == ">" {
                            message.messageId = value
                        } else {
                            // Try wrapping in angle brackets for parsing
                            message.messageId = "<\(value)>"
                        }
                    }
                }
            case .subject:
                if isStringProperty(prop) {
                    message.subject = try prop.readValueAsString()
                }
            case .subjectPrefix:
                if isStringProperty(prop) {
                    subjectPrefix = try prop.readValueAsString()
                }
            case .normalizedSubject:
                if isStringProperty(prop) {
                    normalizedSubject = try prop.readValueAsString()
                }
            case .senderName:
                if isStringProperty(prop) {
                    sender.name = try prop.readValueAsString()
                }
            case .senderEmailAddress:
                if isStringProperty(prop) {
                    sender.addr = try prop.readValueAsString()
                }
            case .senderSearchKey:
                if isStringProperty(prop) {
                    sender.searchKey = try prop.readValueAsString()
                }
            case .senderAddrtype:
                if isStringProperty(prop) {
                    sender.addrType = try prop.readValueAsString()
                }
            case .receivedByName:
                if isStringProperty(prop) {
                    recipient.name = try prop.readValueAsString()
                }
            case .receivedByEmailAddress:
                if isStringProperty(prop) {
                    recipient.addr = try prop.readValueAsString()
                }
            case .receivedBySearchKey:
                if isStringProperty(prop) {
                    recipient.searchKey = try prop.readValueAsString()
                }
            case .receivedByAddrtype:
                if isStringProperty(prop) {
                    recipient.addrType = try prop.readValueAsString()
                }
            case .rtfCompressed:
                if isStringProperty(prop) {
                    let converter = RtfCompressedToRtf()
                    let content = MemoryBlockStream()
                    let filtered = try FilteredStream(content)
                    try filtered.add(converter)
                    let compressed = prop.getRawValueReadStream()
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    while true {
                        let n = try compressed.read(&buffer, offset: 0, count: buffer.count)
                        if n <= 0 { break }
                        try filtered.write(buffer, offset: 0, count: n)
                    }
                    try filtered.flush()
                    content.position = 0
                    let rtf = TextPart("rtf")
                    rtf.content = MimeContent(content)
                    try alternatives.add(rtf)
                }
            case .bodyHtml:
                if isStringProperty(prop) {
                    let html = TextPart("html")
                    if prop.propertyTag.type != .unicode {
                        let (text, encoding) = try getHtmlBody(prop, reader.messageCodepage)
                        html.setText(encoding, text)
                    } else {
                        html.text = try prop.readValueAsString()
                    }
                    try alternatives.add(html)
                }
            case .body:
                if isStringProperty(prop) {
                    let plain = TextPart("plain")
                    plain.text = try prop.readValueAsString()
                    try alternatives.add(plain)
                }
            case .importance:
                let val = try prop.readValueAsInt32()
                switch val {
                case 2: message.importance = .high
                case 1: message.importance = .normal
                case 0: message.importance = .low
                default: break
                }
            case .priority:
                let val = try prop.readValueAsInt32()
                switch val {
                case 1: message.priority = .urgent
                case 0: message.priority = .normal
                case -1: message.priority = .nonUrgent
                default: break
                }
            case .sensitivity:
                // https://msdn.microsoft.com/en-us/library/ee217353(v=exchg.80).aspx
                // https://tools.ietf.org/html/rfc2156#section-5.3.4
                let val = try prop.readValueAsInt32()
                switch val {
                case 1: message.headers[.sensitivity] = "Personal"
                case 2: message.headers[.sensitivity] = "Private"
                case 3: message.headers[.sensitivity] = "Company-Confidential"
                case 0: message.headers.removeAll(.sensitivity)
                default: break
                }
            default:
                break
            }
        }

        if message.subject?.isEmpty ?? true, let normalized = normalizedSubject {
            if let prefix = subjectPrefix {
                message.subject = prefix + normalized
            } else {
                message.subject = normalized
            }
        }

        if let mailbox = sender.tryGetMailboxAddress() {
            message.from.add(mailbox)
        }
        if let mailbox = recipient.tryGetMailboxAddress() {
            message.to.add(mailbox)
        }
    }

    private static func promoteToTnefPart(_ part: MimePart) -> TnefPart {
        let tnef = TnefPart()

        for param in part.contentType.parameters {
            tnef.contentType.parameters[param.name] = param.value
        }

        if let contentDisposition = part.contentDisposition {
            tnef.contentDisposition = contentDisposition.copy()
        }

        tnef.contentTransferEncoding = part.contentTransferEncoding

        return tnef
    }

    private static func extractAttachments(_ reader: TnefReader, _ attachments: Multipart) throws {
        var attachMethod: TnefAttachMethod = .byValue
        let filter = BestEncodingFilter()
        let prop = reader.tnefPropertyReader!
        var attachment: MimePart? = nil
        var attachData: [UInt8]? = nil

        repeat {
            if reader.attributeLevel != .attachment {
                break
            }

            switch reader.attributeTag {
            case .attachRenderData:
                attachMethod = .byValue
                attachment = MimePart()
            case .attachment:
                guard var part = attachment else { break }
                attachData = nil

                while try prop.readNextProperty() {
                    switch prop.propertyTag.id {
                    case .attachLongFilename:
                        part.fileName = try prop.readValueAsString()
                    case .attachFilename:
                        if part.fileName == nil {
                            part.fileName = try prop.readValueAsString()
                        }
                    case .attachContentLocation:
                        part.contentLocation = try prop.readValueAsUri()
                    case .attachContentBase:
                        part.contentBase = try prop.readValueAsUri()
                    case .attachContentId:
                        let text = try prop.readValueAsString()
                        let buffer = Array(text.utf8)
                        var index = 0
                        var msgid: String? = nil
                        if (try? ParseUtils.tryParseMsgId(buffer, index: &index, endIndex: buffer.count, requireAngleAddr: false, throwOnError: false, msgid: &msgid)) == true,
                           let msgid = msgid {
                            part.contentId = msgid
                        }
                    case .attachDisposition:
                        let text = try prop.readValueAsString()
                        if let disposition = try? ContentDisposition(parsing: text) {
                            part.contentDisposition = disposition
                        }
                    case .attachData:
                        attachData = try prop.readValueAsBytes()
                    case .attachMethod:
                        attachMethod = TnefAttachMethod(rawValue: Int(try prop.readValueAsInt32())) ?? .byValue
                    case .attachMimeTag:
                        let mimeType = try prop.readValueAsString().split(separator: "/")
                        if mimeType.count == 2 {
                            part.contentType.mediaType = String(mimeType[0]).trimmingCharacters(in: .whitespaces)
                            part.contentType.mediaSubtype = String(mimeType[1]).trimmingCharacters(in: .whitespaces)
                        }
                    case .attachFlags:
                        let flags = TnefAttachFlags(rawValue: Int(try prop.readValueAsInt32()))
                        if flags.contains(.renderedInBody) {
                            if part.contentDisposition == nil {
                                part.contentDisposition = try? ContentDisposition(ContentDisposition.inline)
                            } else {
                                try? part.contentDisposition?.setDisposition(ContentDisposition.inline)
                            }
                        }
                    case .attachSize:
                        if part.contentDisposition == nil {
                            part.contentDisposition = try? ContentDisposition()
                        }
                        part.contentDisposition?.size = try prop.readValueAsInt64()
                    case .displayName:
                        part.contentType.name = try prop.readValueAsString()
                    default:
                        break
                    }
                }

                if let data = attachData {
                    var index = 0
                    var count = data.count

                    if attachMethod == .embeddedMessage {
                        part.contentTransferEncoding = .base64
                        part = promoteToTnefPart(part)
                        attachment = part
                        count -= 16
                        index = 16
                    } else if part.contentType.isMimeType("text", "*") {
                        var outputIndex = 0
                        var outputLength = 0
                        _ = filter.flush(Array(data[index..<(index + count)]), startIndex: 0, length: count, outputIndex: &outputIndex, outputLength: &outputLength)
                        part.contentTransferEncoding = (try? filter.getBestEncoding(.sevenBit)) ?? .base64
                        filter.reset()
                    } else {
                        part.contentTransferEncoding = .base64
                    }

                    part.content = MimeContent(MemoryStream(Array(data[index..<(index + count)]), writable: false))
                    try attachments.add(part)
                }
            case .attachCreateDate:
                if let part = attachment {
                    if part.contentDisposition == nil {
                        part.contentDisposition = try? ContentDisposition()
                    }
                    part.contentDisposition?.creationDate = try prop.readValueAsDateTime()
                }
            case .attachModifyDate:
                if let part = attachment {
                    if part.contentDisposition == nil {
                        part.contentDisposition = try? ContentDisposition()
                    }
                    part.contentDisposition?.modificationDate = try prop.readValueAsDateTime()
                }
            case .attachTitle:
                if let part = attachment, part.fileName?.isEmpty ?? true {
                    part.fileName = try prop.readValueAsString()
                }
            case .attachData:
                guard let part = attachment, attachMethod == .byValue else { break }

                let data = try prop.readValueAsBytes()
                attachData = data

                if part.contentType.isMimeType("text", "*") {
                    var outputIndex = 0
                    var outputLength = 0
                    _ = filter.flush(data, startIndex: 0, length: data.count, outputIndex: &outputIndex, outputLength: &outputLength)
                    part.contentTransferEncoding = (try? filter.getBestEncoding(.sevenBit)) ?? .base64
                    filter.reset()
                } else {
                    part.contentTransferEncoding = .base64
                }

                part.content = MimeContent(MemoryStream(data, writable: false))
                try attachments.add(part)
            default:
                break
            }
        } while try reader.readNextAttribute()
    }

    /// Extract the embedded attachments from the TNEF data.
    ///
    /// Parses the TNEF data and extracts all the embedded file attachments.
    ///
    /// - Returns: An array of extracted MIME entities.
    /// - Throws: ``StreamError/notSupported`` if the ``MimePart/content`` property is `nil`.
    public func extractAttachments() throws -> [MimeEntity] {
        let message = try convertToMessage()
        let body = message.body
        message.body = nil

        var results = [MimeEntity]()

        if let multipart = body as? Multipart {
            if multipart.count > 0, let alternatives = multipart[0] as? MultipartAlternative {
                for i in 0..<alternatives.count {
                    results.append(alternatives[i])
                }
                alternatives.clear()
                try multipart.remove(at: 0)
            }

            for i in 0..<multipart.count {
                results.append(multipart[i])
            }

            multipart.clear()
        } else if let entity = body {
            results.append(entity)
        }

        return results
    }
}
