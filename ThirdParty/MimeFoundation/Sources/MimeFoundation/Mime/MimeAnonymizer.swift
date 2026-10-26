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
// MimeAnonymizer.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum MimeAnonymizerError: Error, Equatable, Sendable {
}

public final class MimeAnonymizer {
    private static let addressSpecials = Array(" \t\r\n()<>[]:;@,.".utf8)
    private static let receivedSpecials = Array("<>[]:@,.".utf8)
    private static let receivedFrom = Array("from".utf8)
    private static let receivedBy = Array("by".utf8)
    private static let receivedVia = Array("via".utf8)
    private static let receivedWith = Array("with".utf8)
    private static let receivedId = Array("id".utf8)
    private static let receivedFor = Array("for".utf8)
    private static let boundaryParameter = Array("boundary".utf8)
    private static let charsetParameter = Array("charset".utf8)
    private static let delspParameter = Array("delsp".utf8)
    private static let formatParameter = Array("format".utf8)
    private static let whitespace = Array(" \t\r\n".utf8)

    private var preserveHeadersStorage: Set<String>

    public init() {
        preserveHeadersStorage = []
    }

    public var preserveHeaders: Set<String> {
        get { preserveHeadersStorage }
        set { preserveHeadersStorage = Set(newValue.map { $0.lowercased() }) }
    }

    public func anonymize(_ message: MimeMessage, _ stream: MimeStream) throws {
        try anonymize(.default, message, stream)
    }

    public func anonymize(_ options: FormatOptions, _ message: MimeMessage, _ stream: MimeStream) throws {
        try anonymizeMessage(options, message, stream)
    }

    public func anonymize(_ entity: MimeEntity, _ stream: MimeStream) throws {
        try anonymize(.default, entity, stream)
    }

    public func anonymize(_ options: FormatOptions, _ entity: MimeEntity, _ stream: MimeStream) throws {
        try anonymizeEntity(options, entity, stream, contentOnly: false)
    }

    internal static func anonymizeReceivedHeaderValue(_ rawValue: [UInt8]) -> [UInt8] {
        var anonymized = [UInt8](repeating: 0, count: rawValue.count)
        var index = 0

        while index < rawValue.count {
            while index < rawValue.count && ByteClassification.isWhitespace(rawValue[index]) {
                anonymized[index] = rawValue[index]
                index += 1
            }

            if index >= rawValue.count {
                break
            }

            if rawValue[index] == UInt8(ascii: "(") {
                var commentDepth = 1
                var escaped = false

                anonymized[index] = rawValue[index]
                index += 1

                while index < rawValue.count && commentDepth > 0 {
                    if rawValue[index] == UInt8(ascii: "\\") {
                        anonymized[index] = rawValue[index]
                        escaped.toggle()
                    } else if !escaped {
                        if rawValue[index] == UInt8(ascii: "(") {
                            anonymized[index] = rawValue[index]
                            commentDepth += 1
                        } else if rawValue[index] == UInt8(ascii: ")") {
                            anonymized[index] = rawValue[index]
                            commentDepth -= 1
                        } else if ByteClassification.isWhitespace(rawValue[index]) {
                            anonymized[index] = rawValue[index]
                        } else if receivedSpecials.contains(rawValue[index]) {
                            anonymized[index] = rawValue[index]
                        } else {
                            anonymized[index] = UInt8(ascii: "x")
                        }
                    } else {
                        anonymized[index] = UInt8(ascii: "x")
                        escaped = false
                    }

                    index += 1
                }
            } else if rawValue[index] == UInt8(ascii: ";") {
                anonymized[index] = rawValue[index]
                index += 1

                while index < rawValue.count && ByteClassification.isWhitespace(rawValue[index]) {
                    anonymized[index] = rawValue[index]
                    index += 1
                }

                var date: DateTimeOffset? = nil
                if DateUtils.tryParse(rawValue, startIndex: index, date: &date) {
                    if index < rawValue.count {
                        anonymized.replaceSubrange(index..<rawValue.count, with: rawValue[index..<rawValue.count])
                    }
                    break
                }
            } else {
                var length = 0
                if isReceivedKeyword(rawValue, index, length: &length) {
                    if length > 0 {
                        anonymized.replaceSubrange(index..<(index + length), with: rawValue[index..<(index + length)])
                        index += length
                    }
                } else {
                    while index < rawValue.count {
                        if ByteClassification.isWhitespace(rawValue[index]) || rawValue[index] == UInt8(ascii: ";") || rawValue[index] == UInt8(ascii: "(") {
                            break
                        }

                        if receivedSpecials.contains(rawValue[index]) {
                            anonymized[index] = rawValue[index]
                        } else {
                            anonymized[index] = UInt8(ascii: "x")
                        }
                        index += 1
                    }
                }
            }
        }

        return anonymized
    }

    internal static func anonymizeAddressHeaderValue(_ rawValue: [UInt8]) -> [UInt8] {
        var anonymized = [UInt8](repeating: 0, count: rawValue.count)
        var state = Rfc2047EncodedWordState.none
        var escaped = false
        var quoted = false

        var index = 0
        while index < rawValue.count {
            let byte = rawValue[index]

            if byte == UInt8(ascii: "\\") {
                anonymized[index] = byte
                escaped.toggle()
            } else if byte == UInt8(ascii: "\"") {
                anonymized[index] = byte
                if escaped {
                    escaped = false
                } else {
                    quoted.toggle()
                }
            } else if escaped {
                anonymized[index] = byte
                escaped = false
            } else if quoted {
                if byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\n") {
                    anonymized[index] = byte
                } else {
                    anonymized[index] = UInt8(ascii: "x")
                }
            } else {
                pushPotentialRfc2047EncodedWordByte(&state, rawValue, index: &index, anonymized: &anonymized, specials: addressSpecials)
            }

            index += 1
        }

        return anonymized
    }

    internal static func anonymizeUnstructuredHeaderValue(_ rawValue: [UInt8]) -> [UInt8] {
        var anonymized = [UInt8](repeating: 0, count: rawValue.count)
        var state = Rfc2047EncodedWordState.none
        var index = 0

        while index < rawValue.count {
            pushPotentialRfc2047EncodedWordByte(&state, rawValue, index: &index, anonymized: &anonymized, specials: whitespace)
            index += 1
        }

        return anonymized
    }

    internal static func anonymizeContentDispositionValue(_ rawValue: [UInt8]) -> [UInt8] {
        var anonymized = [UInt8](repeating: 0, count: rawValue.count)
        var index = 0

        while index < rawValue.count && rawValue[index] != UInt8(ascii: ";") {
            anonymized[index] = rawValue[index]
            index += 1
        }

        anonymizeParameterList(rawValue, anonymized: &anonymized, startIndex: index)
        return anonymized
    }

    internal static func anonymizeContentTypeValue(_ rawValue: [UInt8]) -> [UInt8] {
        var anonymized = [UInt8](repeating: 0, count: rawValue.count)
        var index = 0

        while index < rawValue.count && rawValue[index] != UInt8(ascii: ";") {
            anonymized[index] = rawValue[index]
            index += 1
        }

        anonymizeParameterList(rawValue, anonymized: &anonymized, startIndex: index)
        return anonymized
    }

    private func anonymizeHeader(_ options: FormatOptions, _ header: Header) -> [UInt8] {
        let rawValue = header.getRawValue(options)
        if preserveHeadersStorage.contains(header.field.lowercased()) {
            return rawValue
        }

        switch header.id {
        case .dispositionNotificationTo, .resentReplyTo, .resentSender, .resentFrom, .resentBcc, .resentCc, .resentTo,
                .replyTo, .sender, .from, .bcc, .cc, .to:
            return Self.anonymizeAddressHeaderValue(rawValue)
        case .received:
            return Self.anonymizeReceivedHeaderValue(rawValue)
        case .originalMessageId, .resentMessageId, .references, .inReplyTo, .messageId, .contentId:
            return Self.anonymizeAddressHeaderValue(rawValue)
        case .contentDisposition:
            return Self.anonymizeContentDispositionValue(rawValue)
        case .contentType:
            return Self.anonymizeContentTypeValue(rawValue)
        case .arcAuthenticationResults, .authenticationResults, .arcMessageSignature, .arcSeal, .dkimSignature:
            return Self.anonymizeUnstructuredHeaderValue(rawValue)
        case .contentTransferEncoding, .mimeVersion, .date:
            return rawValue
        default:
            return Self.anonymizeUnstructuredHeaderValue(rawValue)
        }
    }

    private func anonymizeHeaders(_ options: FormatOptions, _ headers: HeaderList, _ stream: MimeStream) throws {
        let filtered = try FilteredStream(stream)
        let newLineFilter = createNewLineFilter(options, ensureNewLine: false)
        try filtered.add(newLineFilter)

        let colon = UInt8(ascii: ":")
        for header in headers {
            if !Self.isValidFieldName(header.field) {
                try anonymizeBytes(options, stream: stream, rawValue: header.rawField, ensureNewLine: false)
                continue
            }
            let rawValue = anonymizeHeader(options, header)
            try filtered.write(header.rawField, offset: 0, count: header.rawField.count)
            try filtered.write([colon], offset: 0, count: 1)
            try filtered.write(rawValue, offset: 0, count: rawValue.count)
        }

        try filtered.flush()
    }

    private func anonymizeMessage(_ options: FormatOptions, _ message: MimeMessage, _ stream: MimeStream) throws {
        let merged = mergeHeaders(message.headers, message.body)
        do {
            try anonymizeHeaders(options, merged, stream)
        } catch {
            print("MimeAnonymizer.anonymizeMessage headers error: \(type(of: error)) \(error)")
            throw error
        }
        if let body = message.body {
            try stream.write(options.newLineBytes, offset: 0, count: options.newLineBytes.count)
            do {
                try anonymizeEntity(options, body, stream, contentOnly: true)
            } catch {
                print("MimeAnonymizer.anonymizeMessage body error: \(type(of: error)) \(error)")
                throw error
            }
        }
    }

    private func anonymizeEntity(_ options: FormatOptions, _ entity: MimeEntity, _ stream: MimeStream, contentOnly: Bool) throws {
        if !contentOnly {
            try anonymizeHeaders(options, entity.headers, stream)
            try stream.write(options.newLineBytes, offset: 0, count: options.newLineBytes.count)
        }

        if let messagePart = entity as? MessagePart {
            if let message = messagePart.message {
                try anonymizeMessage(options, message, stream)
            }
            return
        }

        if let multipart = entity as? Multipart {
            let boundaryBytes = options.newLineBytes
            let boundaryMarker = Self.generateBoundaryMarker(boundary: multipart.boundary, newLine: boundaryBytes)
            let endMarker = Self.generateEndBoundaryMarker(boundary: multipart.boundary, newLine: boundaryBytes)

            if let preamble = multipart.preamble {
                do {
                    try anonymizeBytes(options, stream: stream, rawValue: Array(preamble.utf8), ensureNewLine: multipart.count > 0 || options.ensureNewLine)
                } catch {
                    print("MimeAnonymizer.multipart preamble error: \(type(of: error)) \(error)")
                    throw error
                }
            }

            for part in multipart {
                do {
                    try stream.write(boundaryMarker, offset: 0, count: boundaryMarker.count)
                } catch {
                    print("MimeAnonymizer.multipart boundary write error: \(type(of: error)) \(error)")
                    throw error
                }
                do {
                    try anonymizeEntity(options, part, stream, contentOnly: false)
                } catch {
                    print("MimeAnonymizer.multipart part error: \(type(of: error)) \(error)")
                    throw error
                }
                if shouldWriteNewLine(after: part) {
                    do {
                        try stream.write(boundaryBytes, offset: 0, count: boundaryBytes.count)
                    } catch {
                        print("MimeAnonymizer.multipart newline write error: \(type(of: error)) \(error)")
                        throw error
                    }
                }
            }

            if multipart.writeEndBoundary {
                do {
                    try stream.write(endMarker, offset: 0, count: endMarker.count)
                } catch {
                    print("MimeAnonymizer.multipart end boundary write error: \(type(of: error)) \(error)")
                    throw error
                }
            }

            if let epilogue = multipart.epilogue {
                do {
                    try anonymizeBytes(options, stream: stream, rawValue: Array(epilogue.utf8), ensureNewLine: options.ensureNewLine)
                } catch {
                    print("MimeAnonymizer.multipart epilogue error: \(type(of: error)) \(error)")
                    throw error
                }
            }

            return
        }

        if let delivery = entity as? MessageDeliveryStatus {
            let groups = delivery.statusGroups
            for index in 0..<groups.count {
                try anonymizeHeaders(options, groups[index], stream)
                if index + 1 < groups.count {
                    try stream.write(options.newLineBytes, offset: 0, count: options.newLineBytes.count)
                }
            }
            return
        }

        if let mdn = entity as? MessageDispositionNotification {
            try anonymizeHeaders(options, mdn.fields, stream)
            return
        }

        if let feedback = entity as? MessageFeedbackReport {
            try anonymizeHeaders(options, feedback.fields, stream)
            return
        }

        let filtered = try FilteredStream(stream)
        try filtered.add(AnonymizeFilter())
        do {
            try entity.writeBody(options, stream: filtered)
        } catch {
            print("MimeAnonymizer.entity writeBody error: \(type(of: error)) \(error)")
            throw error
        }
        try filtered.flush()
    }

    private func mergeHeaders(_ headers: HeaderList, _ body: MimeEntity?) -> HeaderList {
        let merged = HeaderList()
        for header in headers {
            merged.add(header.copy())
        }
        if let body {
            if headers[.mimeVersion] == nil && !body.headers.isEmpty {
                merged.add(Header(.mimeVersion, value: "1.0"))
            }
            for header in body.headers where header.field.lowercased().hasPrefix("content-") {
                if header.id != .unknown {
                    if merged.contains(header.id) {
                        continue
                    }
                } else if merged.contains(field: header.field) {
                    continue
                }
                merged.add(header.copy())
            }
        }
        return merged
    }

    private func shouldWriteNewLine(after part: MimeEntity) -> Bool {
        if let mimePart = part as? MimePart {
            return mimePart.content != nil
        }
        if let messagePart = part as? MessagePart {
            return messagePart.message?.body != nil
        }
        if let multipart = part as? Multipart {
            return multipart.writeEndBoundary
        }
        return true
    }

    private func createNewLineFilter(_ options: FormatOptions, ensureNewLine: Bool) -> MimeFilter {
        switch options.newLineFormat {
        case .unix:
            return Dos2UnixFilter(ensureNewLine)
        case .mixed, .dos:
            return Unix2DosFilter(ensureNewLine)
        }
    }

    private static func generateBoundaryMarker(boundary: String, newLine: [UInt8]) -> [UInt8] {
        var marker: [UInt8] = [UInt8(ascii: "-"), UInt8(ascii: "-")]
        marker.append(contentsOf: boundary.utf8)
        marker.append(contentsOf: newLine)
        return marker
    }

    private static func generateEndBoundaryMarker(boundary: String, newLine: [UInt8]) -> [UInt8] {
        var marker: [UInt8] = [UInt8(ascii: "-"), UInt8(ascii: "-")]
        marker.append(contentsOf: boundary.utf8)
        marker.append(UInt8(ascii: "-"))
        marker.append(UInt8(ascii: "-"))
        marker.append(contentsOf: newLine)
        return marker
    }

    private func anonymizeBytes(_ options: FormatOptions, stream: MimeStream, rawValue: [UInt8]?, ensureNewLine: Bool) throws {
        guard let rawValue, !rawValue.isEmpty else { return }
        let filtered = try FilteredStream(stream)
        try filtered.add(AnonymizeFilter())
        try filtered.add(createNewLineFilter(options, ensureNewLine: ensureNewLine))
        try filtered.write(rawValue, offset: 0, count: rawValue.count)
        try filtered.flush()
    }
}

private enum Rfc2047EncodedWordState {
    case none
    case equals
    case equalsQuestion
    case charset
    case charsetQuestion
    case encoding
    case encodingQuestion
    case payload
    case payloadQuestion
}

private enum ParameterState {
    case semicolon
    case name
    case nameStar
    case value
}

private extension MimeAnonymizer {
    static func isReceivedKeyword(_ rawValue: [UInt8], _ index: Int, length: inout Int) -> Bool {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(4)
        length = 0
        var i = index

        while i < rawValue.count && length < 4 && !ByteClassification.isWhitespace(rawValue[i]) {
            let byte = rawValue[i]
            if byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z") {
                buffer.append(byte + 0x20)
            } else if byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z") {
                buffer.append(byte)
            } else {
                return false
            }
            length += 1
            i += 1
        }

        if i >= rawValue.count || !ByteClassification.isWhitespace(rawValue[i]) {
            return false
        }

        return buffer == receivedFrom ||
            buffer == receivedBy ||
            buffer == receivedVia ||
            buffer == receivedWith ||
            buffer == receivedId ||
            buffer == receivedFor
    }

    static func pushPotentialRfc2047EncodedWordByte(_ state: inout Rfc2047EncodedWordState, _ rawValue: [UInt8], index: inout Int, anonymized: inout [UInt8], specials: [UInt8]) {
        let byte = rawValue[index]

        if byte == UInt8(ascii: "=") {
            switch state {
            case .none:
                state = .equals
                anonymized[index] = byte
            case .payloadQuestion:
                state = .none
                anonymized[index] = byte
            case .payload:
                anonymized[index] = UInt8(ascii: "x")
            default:
                state = .none
                anonymized[index] = byte
            }
            return
        }

        if byte == UInt8(ascii: "?") {
            anonymized[index] = byte
            switch state {
            case .equals:
                state = .equalsQuestion
            case .charset:
                state = .charsetQuestion
            case .encoding:
                state = .encodingQuestion
            case .payload:
                state = .payloadQuestion
            case .none:
                break
            default:
                state = .none
            }
            return
        }

        switch state {
        case .equalsQuestion:
            state = .charset
            anonymized[index] = byte
        case .charset:
            anonymized[index] = byte
        case .charsetQuestion:
            state = .encoding
            anonymized[index] = byte
        case .encoding:
            anonymized[index] = byte
        case .encodingQuestion:
            state = .payload
            fallthrough
        case .payload:
            if ByteClassification.isWhitespace(byte) {
                anonymized[index] = byte
            } else {
                anonymized[index] = UInt8(ascii: "x")
            }
        case .none:
            if specials.contains(byte) {
                anonymized[index] = byte
            } else {
                anonymized[index] = UInt8(ascii: "x")
            }
        default:
            state = .none
            index -= 1
        }
    }

    static func isSafeParameterName(_ name: borrowing ByteArrayBuilder) -> Bool {
        return name.equals(ArraySlice(boundaryParameter), comparison: .insensitiveAscii) ||
            name.equals(ArraySlice(charsetParameter), comparison: .insensitiveAscii) ||
            name.equals(ArraySlice(delspParameter), comparison: .insensitiveAscii) ||
            name.equals(ArraySlice(formatParameter), comparison: .insensitiveAscii)
    }

    static func anonymizeParameterList(_ rawValue: [UInt8], anonymized: inout [UInt8], startIndex: Int) {
        var name = ByteArrayBuilder(initialCapacity: 16)
        var state: ParameterState = .semicolon
        var index = startIndex
        var escaped = false
        var quoted = false
        var safe = false

        if index < rawValue.count {
            anonymized[index] = rawValue[index]
            index += 1
        }

        while index < rawValue.count {
            switch state {
            case .semicolon:
                if rawValue[index] == UInt8(ascii: ";") {
                    anonymized[index] = rawValue[index]
                } else if ByteClassification.isWhitespace(rawValue[index]) {
                    anonymized[index] = rawValue[index]
                } else {
                    state = .name
                    continue
                }
            case .name:
                if rawValue[index] == UInt8(ascii: "=") {
                    anonymized[index] = rawValue[index]
                    safe = isSafeParameterName(name)
                    state = .value
                } else if rawValue[index] == UInt8(ascii: ";") {
                    anonymized[index] = rawValue[index]
                    state = .semicolon
                    name.clear()
                } else if rawValue[index] == UInt8(ascii: "*") {
                    state = .nameStar
                    anonymized[index] = rawValue[index]
                } else {
                    name.append(rawValue[index])
                    anonymized[index] = rawValue[index]
                }
            case .nameStar:
                if rawValue[index] == UInt8(ascii: "=") {
                    anonymized[index] = rawValue[index]
                    safe = isSafeParameterName(name)
                    state = .value
                } else if rawValue[index] == UInt8(ascii: ";") {
                    state = .semicolon
                    anonymized[index] = rawValue[index]
                } else {
                    anonymized[index] = rawValue[index]
                }
            case .value:
                if rawValue[index] == UInt8(ascii: "\"") {
                    anonymized[index] = rawValue[index]
                    if escaped {
                        escaped = false
                    } else {
                        quoted.toggle()
                    }
                } else if quoted {
                    if rawValue[index] == UInt8(ascii: "\\") {
                        anonymized[index] = rawValue[index]
                        escaped.toggle()
                    } else if rawValue[index] == UInt8(ascii: "\r") || rawValue[index] == UInt8(ascii: "\n") {
                        anonymized[index] = rawValue[index]
                        escaped = false
                    } else {
                        anonymized[index] = safe ? rawValue[index] : UInt8(ascii: "x")
                        escaped = false
                    }
                } else if rawValue[index] == UInt8(ascii: ";") {
                    anonymized[index] = rawValue[index]
                    state = .semicolon
                    name.clear()
                } else if ByteClassification.isWhitespace(rawValue[index]) {
                    anonymized[index] = rawValue[index]
                } else if safe {
                    anonymized[index] = rawValue[index]
                } else {
                    anonymized[index] = UInt8(ascii: "x")
                }
            }

            index += 1
        }
    }

    static func isValidFieldName(_ field: String) -> Bool {
        if field.isEmpty {
            return false
        }
        for scalar in field.unicodeScalars {
            if scalar.value >= 127 {
                return false
            }
            let byte = UInt8(scalar.value)
            if byte == 0x3A || byte < 0x21 || byte > 0x7E {
                return false
            }
        }
        return true
    }
}
