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
// MessageDeliveryStatus.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public final class MessageDeliveryStatus: MimePart {
    private var statusGroupsStorage: HeaderListCollection
    private var statusGroupsLoaded = false

    private static var deliveryStatusContentType: ContentType {
        guard let ct = try? ContentType("message", "delivery-status") else {
            preconditionFailure("Invalid static content type - this is a programming error")
        }
        return ct
    }

    public override init(_ contentType: ContentType) {
        self.statusGroupsStorage = HeaderListCollection()
        super.init(contentType)
        configureStatusGroups()
        statusGroupsLoaded = false
    }

    public init() {
        self.statusGroupsStorage = HeaderListCollection()
        super.init(Self.deliveryStatusContentType)
        configureStatusGroups()
        statusGroupsLoaded = true
        updateContentFromStatusGroups()
    }

    public var statusGroups: HeaderListCollection {
        loadStatusGroupsIfNeeded()
        return statusGroupsStorage
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    private func configureStatusGroups() {
        statusGroupsStorage.changed = { [weak self] in
            self?.updateContentFromStatusGroups()
        }
    }

    private func loadStatusGroupsIfNeeded() {
        guard !statusGroupsLoaded else { return }
        statusGroupsLoaded = true

        let groups = HeaderListCollection()
        groups.changed = { [weak self] in
            self?.updateContentFromStatusGroups()
        }
        statusGroupsStorage = groups

        guard let content else { return }
        let bytes = MessageDeliveryStatus.readDecodedBytes(from: content)
        let parsedGroups = MessageDeliveryStatus.parseStatusGroups(bytes)
        for group in parsedGroups {
            statusGroupsStorage.add(group)
        }
    }

    private func updateContentFromStatusGroups() {
        guard statusGroupsLoaded else { return }
        guard !statusGroupsStorage.isEmpty else {
            content = MimeContent(MemoryStream([], writable: false), encoding: .default)
            return
        }

        let options = FormatOptions.default
        var text = ""
        let lastIndex = statusGroupsStorage.count - 1
        for (index, group) in statusGroupsStorage.enumerated() {
            let groupText = group.toString(options, encode: true)
            if !groupText.isEmpty {
                text.append(groupText)
            }
            text.append(options.newLine)
            if index < lastIndex {
                text.append(options.newLine)
            }
        }

        let bytes = Array(text.utf8)
        content = MimeContent(MemoryStream(bytes, writable: false), encoding: .default)
    }

    private static func parseStatusGroups(_ bytes: [UInt8]) -> [HeaderList] {
        var groups: [HeaderList] = []
        guard !bytes.isEmpty else { return groups }

        let text = String(data: Data(bytes), encoding: .isoLatin1) ?? String(decoding: bytes, as: UTF8.self)
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var blocks: [[String]] = []
        var current: [String] = []

        for rawLine in lines {
            let line = String(rawLine)
            if line.isEmpty {
                if !current.isEmpty {
                    blocks.append(current)
                    current.removeAll(keepingCapacity: true)
                }
                continue
            }
            current.append(line)
        }
        if !current.isEmpty {
            blocks.append(current)
        }

        var pendingEncoding: ContentEncoding? = nil
        for block in blocks {
            let headers = parseHeaderBlock(block)
            if headers.count > 0 {
                groups.append(headers)
                if let value = headers["Content-Transfer-Encoding"] {
                    pendingEncoding = parseContentEncoding(value)
                } else {
                    pendingEncoding = nil
                }
                continue
            }

            if let encoding = pendingEncoding {
                let blockText = block.joined(separator: "\n")
                let decoded = decodeContentBytes(Array(blockText.utf8), encoding: encoding)
                let decodedGroups = parseStatusGroups(decoded)
                if !decodedGroups.isEmpty {
                    groups.append(contentsOf: decodedGroups)
                }
                pendingEncoding = nil
            }
        }

        return groups
    }

    private static func parseHeaderBlock(_ lines: [String]) -> HeaderList {
        guard !lines.isEmpty else {
            return HeaderList()
        }
        if !lines.contains(where: { $0.contains(":") }) {
            return HeaderList()
        }
        var text = lines.joined(separator: "\n")
        text.append("\n\n")
        let bytes = Array(text.utf8)
        let (headers, _) = MimeMessage.parseHeaders(bytes)
        return headers
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
                if read == 0 { break }
                output.append(contentsOf: buffer[0..<read])
            }
            return output
        default:
            return bytes
        }
    }

    private static func readDecodedBytes(from content: MimeContent) -> [UInt8] {
        let memory = MemoryStream()
        _ = try? content.decodeTo(memory)
        return memory.toByteArray()
    }
}
