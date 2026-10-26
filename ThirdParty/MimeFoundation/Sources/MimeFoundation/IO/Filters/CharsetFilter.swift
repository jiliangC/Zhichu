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
// CharsetFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum CharsetFilterError: Error, Equatable, Sendable {
    case invalidArgument
    case unsupportedEncoding
}

public final class CharsetFilter: MimeFilterBase {
    public let sourceEncoding: String.Encoding
    public let targetEncoding: String.Encoding

    private var pending: [UInt8] = []

    public init(_ sourceEncodingName: String, _ targetEncodingName: String) throws {
        guard let source = CharsetUtils.getEncoding(sourceEncodingName) else {
            throw CharsetFilterError.unsupportedEncoding
        }
        guard let target = CharsetUtils.getEncoding(targetEncodingName) else {
            throw CharsetFilterError.unsupportedEncoding
        }
        self.sourceEncoding = source
        self.targetEncoding = target
        super.init()
    }

    public init(sourceCodepage: Int, targetCodepage: Int) throws {
        guard sourceCodepage >= 0, sourceCodepage <= 65535,
              targetCodepage >= 0, targetCodepage <= 65535 else {
            throw CharsetFilterError.invalidArgument
        }
        guard let source = CharsetUtils.getEncoding(codepage: sourceCodepage),
              let target = CharsetUtils.getEncoding(codepage: targetCodepage) else {
            throw CharsetFilterError.unsupportedEncoding
        }
        self.sourceEncoding = source
        self.targetEncoding = target
        super.init()
    }

    public init(_ sourceEncoding: String.Encoding, _ targetEncoding: String.Encoding) {
        self.sourceEncoding = sourceEncoding
        self.targetEncoding = targetEncoding
        super.init()
    }

    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        let slice = Array(input[startIndex..<(startIndex + length)])
        if !slice.isEmpty {
            pending.append(contentsOf: slice)
        }

        let processLength = flush ? pending.count : safeDecodeLength(pending)
        let toProcess = Array(pending.prefix(processLength))
        pending.removeFirst(processLength)

        let decoded = decodeBytes(toProcess)
        let encoded = encodeString(decoded)

        ensureOutputSize(encoded.count, preserve: false)
        var output = output
        if !encoded.isEmpty {
            output.replaceSubrange(0..<encoded.count, with: encoded)
        }
        outputIndex = 0
        outputLength = encoded.count
        return output
    }

    public override func reset() {
        pending.removeAll(keepingCapacity: true)
        super.reset()
    }

    private func decodeBytes(_ bytes: [UInt8]) -> String {
        if bytes.isEmpty {
            return ""
        }
        if let string = String(bytes: bytes, encoding: sourceEncoding) {
            return string
        }
        if let string = String(bytes: bytes, encoding: .isoLatin1) {
            return string
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func encodeString(_ string: String) -> [UInt8] {
        if string.isEmpty {
            return []
        }
        if let data = string.data(using: targetEncoding, allowLossyConversion: true) {
            return Array(data)
        }
        return Array(string.utf8)
    }

    private func safeDecodeLength(_ bytes: [UInt8]) -> Int {
        guard sourceEncoding == .utf8, !bytes.isEmpty else {
            return bytes.count
        }
        let maxCheck = min(4, bytes.count)
        var index = bytes.count - 1
        var continuationCount = 0

        while index >= 0 && continuationCount < maxCheck {
            if bytes[index] & 0xC0 == 0x80 {
                continuationCount += 1
                index -= 1
            } else {
                break
            }
        }

        if index < 0 {
            return bytes.count
        }

        let first = bytes[index]
        let expectedLength: Int
        if first & 0x80 == 0x00 {
            expectedLength = 1
        } else if first & 0xE0 == 0xC0 {
            expectedLength = 2
        } else if first & 0xF0 == 0xE0 {
            expectedLength = 3
        } else if first & 0xF8 == 0xF0 {
            expectedLength = 4
        } else {
            expectedLength = 1
        }

        let actualLength = bytes.count - index
        if actualLength < expectedLength {
            return index
        }
        return bytes.count
    }
}
