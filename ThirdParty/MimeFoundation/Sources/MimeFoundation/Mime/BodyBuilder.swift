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
// BodyBuilder.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public final class BodyBuilder {
    public private(set) var attachments: AttachmentCollection
    public private(set) var linkedResources: AttachmentCollection
    public let mimeTypes: MimeTypeRegistry

    public var textBody: String?
    public var htmlBody: String?

    private var bodyEncodingStorage: String.Encoding

    public init(mimeTypes: MimeTypeRegistry = .default) {
        self.mimeTypes = mimeTypes
        self.attachments = AttachmentCollection(false, mimeTypes: mimeTypes)
        self.linkedResources = AttachmentCollection(true, mimeTypes: mimeTypes)
        self.bodyEncodingStorage = .utf8
    }

    public var bodyEncoding: String.Encoding {
        get { bodyEncodingStorage }
        set { bodyEncodingStorage = newValue }
    }

    public func toMessageBody() throws -> MimeEntity {
        var alternative: MultipartAlternative? = nil
        var body: MimeEntity? = nil

        if let textBody {
            let text = TextPart("plain")
            text.setText(bodyEncodingStorage, textBody)

            if htmlBody != nil {
                let alt = MultipartAlternative()
                try alt.add(text)
                alternative = alt
                body = alt
            } else {
                body = text
            }
        }

        if let htmlBody {
            let text = TextPart("html")
            text.setText(bodyEncodingStorage, htmlBody)
            let htmlPart: MimeEntity

            if linkedResources.count > 0 {
                let related = MultipartRelated()
                try related.setRoot(text)
                for resource in linkedResources {
                    try related.add(resource)
                }
                htmlPart = related
            } else {
                htmlPart = text
            }

            if let alternative {
                try alternative.add(htmlPart)
            } else {
                body = htmlPart
            }
        }

        if attachments.count > 0 {
            if body == nil && attachments.count == 1 {
                return attachments[0]
            }

            let mixed = try Multipart("mixed")
            if let body {
                try mixed.add(body)
            }
            for attachment in attachments {
                try mixed.add(attachment)
            }
            body = mixed
        }

        if body == nil {
            let text = TextPart("plain")
            text.setText(bodyEncodingStorage, "")
            body = text
        }

        return body!
    }
}
