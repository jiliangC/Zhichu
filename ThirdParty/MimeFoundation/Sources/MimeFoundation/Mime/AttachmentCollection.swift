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
// AttachmentCollection.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum AttachmentCollectionError: Error, Equatable, Sendable {
    case emptyFileName
    case indexOutOfRange(index: Int, count: Int)
    case invalidMessage
}

public final class AttachmentCollection: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    public typealias Element = MimeEntity
    public typealias Index = Int

    private static var octetStreamContentType: ContentType {
        guard let ct = try? ContentType("application", "octet-stream") else {
            preconditionFailure("Invalid static content type - this is a programming error")
        }
        return ct
    }

    private var attachments: [MimeEntity]
    private let linkedResources: Bool
    private let mimeTypes: MimeTypeRegistry

    public init() {
        self.attachments = []
        self.linkedResources = false
        self.mimeTypes = .default
    }

    public init(_ linkedResources: Bool, mimeTypes: MimeTypeRegistry = .default) {
        self.attachments = []
        self.linkedResources = linkedResources
        self.mimeTypes = mimeTypes
    }

    public var startIndex: Int { attachments.startIndex }
    public var endIndex: Int { attachments.endIndex }

    public func index(after i: Int) -> Int { attachments.index(after: i) }

    public var count: Int { attachments.count }
    public var isReadOnly: Bool { false }

    public subscript(position: Int) -> MimeEntity {
        get { attachments[position] }
        set { attachments[position] = newValue }
    }

    public func add(_ entity: MimeEntity) -> MimeEntity {
        append(entity)
    }

    public func add(fileName: String) throws -> MimeEntity {
        try validateFileName(fileName)
        let contentType = contentType(for: fileName)
        let data = try readFileBytes(fileName)
        let attachment = try createAttachment(contentType: contentType, autoDetected: true, path: fileName, data: data)
        return append(attachment)
    }

    public func add(fileName: String, contentType: ContentType) throws -> MimeEntity {
        try validateFileName(fileName)
        let data = try readFileBytes(fileName)
        let attachment = try createAttachment(contentType: contentType, autoDetected: false, path: fileName, data: data)
        return append(attachment)
    }

    public func add(fileName: String, data: [UInt8]) throws -> MimeEntity {
        try validateFileName(fileName)
        let contentType = contentType(for: fileName)
        let attachment = try createAttachment(contentType: contentType, autoDetected: true, path: fileName, data: data)
        return append(attachment)
    }

    public func add(fileName: String, data: [UInt8], contentType: ContentType) throws -> MimeEntity {
        try validateFileName(fileName)
        let attachment = try createAttachment(contentType: contentType, autoDetected: false, path: fileName, data: data)
        return append(attachment)
    }

    public func add(fileName: String, stream: MimeStream) throws -> MimeEntity {
        try validateFileName(fileName)
        let data = try readAllBytes(from: stream)
        let contentType = contentType(for: fileName)
        let attachment = try createAttachment(contentType: contentType, autoDetected: true, path: fileName, data: data)
        return append(attachment)
    }

    public func add(fileName: String, stream: MimeStream, contentType: ContentType) throws -> MimeEntity {
        try validateFileName(fileName)
        let data = try readAllBytes(from: stream)
        let attachment = try createAttachment(contentType: contentType, autoDetected: false, path: fileName, data: data)
        return append(attachment)
    }

    public func addAsync(fileName: String) async throws -> MimeEntity {
        try add(fileName: fileName)
    }

    public func addAsync(fileName: String, contentType: ContentType) async throws -> MimeEntity {
        try add(fileName: fileName, contentType: contentType)
    }

    public func addAsync(fileName: String, data: [UInt8]) async throws -> MimeEntity {
        try add(fileName: fileName, data: data)
    }

    public func addAsync(fileName: String, data: [UInt8], contentType: ContentType) async throws -> MimeEntity {
        try add(fileName: fileName, data: data, contentType: contentType)
    }

    public func addAsync(fileName: String, stream: MimeStream) async throws -> MimeEntity {
        try add(fileName: fileName, stream: stream)
    }

    public func addAsync(fileName: String, stream: MimeStream, contentType: ContentType) async throws -> MimeEntity {
        try add(fileName: fileName, stream: stream, contentType: contentType)
    }

    public func contains(_ entity: MimeEntity) -> Bool {
        attachments.contains(where: { $0 === entity })
    }

    public func indexOf(_ entity: MimeEntity) -> Int {
        attachments.firstIndex(where: { $0 === entity }) ?? -1
    }

    @discardableResult
    public func remove(_ entity: MimeEntity) -> Bool {
        guard let index = attachments.firstIndex(where: { $0 === entity }) else {
            return false
        }
        attachments.remove(at: index)
        return true
    }

    public func remove(at index: Int) throws {
        guard index >= 0 && index < attachments.count else {
            throw AttachmentCollectionError.indexOutOfRange(index: index, count: attachments.count)
        }
        attachments.remove(at: index)
    }

    public func insert(_ entity: MimeEntity, at index: Int) throws {
        guard index >= 0 && index <= attachments.count else {
            throw AttachmentCollectionError.indexOutOfRange(index: index, count: attachments.count)
        }
        attachments.insert(entity, at: index)
    }

    public func copyTo(_ array: inout [MimeEntity], startingAt index: Int) throws {
        guard index >= 0 && index <= array.count else {
            throw AttachmentCollectionError.indexOutOfRange(index: index, count: array.count)
        }
        array.insert(contentsOf: attachments, at: index)
    }

    public func clear(_ dispose: Bool = false) {
        attachments.removeAll(keepingCapacity: true)
        _ = dispose
    }

    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == MimeEntity {
        attachments.replaceSubrange(subrange, with: newElements)
    }

    private func append(_ attachment: MimeEntity) -> MimeEntity {
        attachments.append(attachment)
        return attachment
    }

    private func validateFileName(_ fileName: String) throws {
        guard !fileName.isEmpty else {
            throw AttachmentCollectionError.emptyFileName
        }
    }

    private func readFileBytes(_ fileName: String) throws -> [UInt8] {
        let url = URL(fileURLWithPath: fileName)
        let data = try Data(contentsOf: url)
        return Array(data)
    }

    private func readAllBytes(from stream: MimeStream) throws -> [UInt8] {
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

    private func createAttachment(contentType: ContentType, autoDetected: Bool, path: String, data: [UInt8]) throws -> MimeEntity {
        let fileName = fileNameFromPath(path)
        var attachment: MimeEntity? = nil

        if contentType.isMimeType("message", "rfc822") {
            if autoDetected, !looksLikeMessage(data) {
                let fallback = try ContentType("application", "octet-stream")
                attachment = createStreamAttachment(contentType: fallback, data: data)
            } else {
                do {
                    let message = try MimeMessage.load(MemoryStream(data, writable: false))
                    if message.headers.count == 0 {
                        throw AttachmentCollectionError.invalidMessage
                    }
                    let part = MessagePart()
                    part.message = message
                    attachment = part
                } catch {
                    if autoDetected {
                        let fallback = try ContentType("application", "octet-stream")
                        attachment = createStreamAttachment(contentType: fallback, data: data)
                    } else {
                        throw error
                    }
                }
            }
        }

        if attachment == nil {
            attachment = createStreamAttachment(contentType: contentType, data: data)
        }

        if let attachment {
            let disposition = try ContentDisposition(linkedResources ? ContentDisposition.inline : ContentDisposition.attachment)
            disposition.fileName = fileName
            attachment.contentDisposition = disposition
            attachment.contentType.name = fileName
            if linkedResources {
                attachment.contentLocation = URL(string: fileName)
            }
            return attachment
        }

        throw AttachmentCollectionError.invalidMessage
    }

    private func createStreamAttachment(contentType: ContentType, data: [UInt8]) -> MimeEntity {
        let isText = contentType.isMimeType("text", "*")
        let part: MimePart
        if isText {
            part = TextPart(contentType)
            part.contentTransferEncoding = .sevenBit
        } else {
            part = MimePart(contentType)
            part.contentTransferEncoding = .base64
        }
        part.content = MimeContent(MemoryStream(data, writable: false))
        return part
    }

    private func fileNameFromPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    private func contentType(for path: String) -> ContentType {
        let mimeType = mimeTypes.mimeType(for: path)
        if let slashIndex = mimeType.firstIndex(of: "/") {
            let type = String(mimeType[..<slashIndex])
            let subtype = String(mimeType[mimeType.index(after: slashIndex)...])
            if let contentType = try? ContentType(type, subtype) {
                return contentType
            }
        }
        return Self.octetStreamContentType
    }

    private func looksLikeMessage(_ data: [UInt8]) -> Bool {
        if data.isEmpty {
            return false
        }
        var line: [UInt8] = []
        for byte in data {
            if byte == 0x0A || byte == 0x0D {
                break
            }
            line.append(byte)
            if line.count > 200 {
                break
            }
        }
        guard let colonIndex = line.firstIndex(of: UInt8(ascii: ":")) else {
            return false
        }
        if colonIndex == 0 {
            return false
        }
        for byte in line[0..<colonIndex] {
            if !isFieldText(byte) {
                return false
            }
        }
        return true
    }

    private func isFieldText(_ byte: UInt8) -> Bool {
        if byte == UInt8(ascii: ":") {
            return false
        }
        if byte < 0x21 || byte > 0x7E {
            return false
        }
        return true
    }
}
