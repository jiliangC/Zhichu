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
// MessagePartial.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum MessagePartialError: Error, Equatable, Sendable {
    case invalidId
    case invalidNumber
    case invalidTotal
    case emptyParts
    case inconsistentId
    case invalidPartNumbers
    case missingContent
}

public final class MessagePartial: MimePart {
    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    public init(_ id: String, _ number: Int, _ total: Int) throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MessagePartialError.invalidId
        }
        guard number >= 1 else {
            throw MessagePartialError.invalidNumber
        }
        guard total >= number else {
            throw MessagePartialError.invalidTotal
        }
        let contentType = try ContentType("message", "partial")
        super.init(contentType)
        self.contentType.parameters["id"] = trimmed
        self.contentType.parameters["number"] = String(number)
        self.contentType.parameters["total"] = String(total)
    }

    public var id: String? {
        contentType.parameters["id"]
    }

    public var number: Int? {
        guard let text = contentType.parameters["number"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Int(text) else {
            return nil
        }
        return value
    }

    public var total: Int? {
        guard let text = contentType.parameters["total"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Int(text) else {
            return nil
        }
        return value
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    public static func split(_ message: MimeMessage, maxSize: Int) throws -> [MimeMessage] {
        guard maxSize > 0 else {
            throw MessagePartialError.invalidTotal
        }

        let bytes = try MessagePartial.serializeMessage(message)
        let id = MimeUtils.generateMessageId()
        let chunks = bytes.chunked(maxSize)
        let total = chunks.count

        var result: [MimeMessage] = []
        for (index, chunk) in chunks.enumerated() {
            let partial = try MessagePartial(id, index + 1, total)
            partial.content = MimeContent(MemoryStream(chunk, writable: false), encoding: .default)

            let partMessage = MimeMessage()
            partMessage.subject = message.subject
            partMessage.body = partial
            result.append(partMessage)
        }

        return result
    }

    public static func join(_ template: MimeMessage, _ partials: [MessagePartial]) throws -> MimeMessage {
        guard !partials.isEmpty else {
            throw MessagePartialError.emptyParts
        }

        guard let id = partials.first?.id else {
            throw MessagePartialError.invalidId
        }
        let totals = Set(partials.compactMap { $0.total })
        if totals.count != 1, let total = totals.first, total < partials.count {
            throw MessagePartialError.invalidTotal
        }

        for part in partials {
            guard part.id == id else {
                throw MessagePartialError.inconsistentId
            }
            guard part.number != nil else {
                throw MessagePartialError.invalidPartNumbers
            }
        }

        let ordered = partials.sorted { ($0.number ?? 0) < ($1.number ?? 0) }
        var data: [UInt8] = []
        for part in ordered {
            guard let content = part.content else {
                throw MessagePartialError.missingContent
            }
            data.append(contentsOf: readContentBytes(from: content))
        }

        let stream = MemoryStream(data, writable: false)
        let message = try MimeMessage.load(stream)
        message.subject = message.subject ?? template.subject
        return message
    }

    private static func serializeMessage(_ message: MimeMessage) throws -> [UInt8] {
        let stream = MemoryStream()
        try message.writeTo(.default, stream)
        return stream.toByteArray()
    }

    private static func readContentBytes(from content: MimeContent) -> [UInt8] {
        let stream = MemoryStream()
        _ = try? content.decodeTo(stream)
        return stream.toByteArray()
    }
}

private extension Array where Element == UInt8 {
    func chunked(_ size: Int) -> [[UInt8]] {
        guard size > 0 else { return [] }
        var chunks: [[UInt8]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
