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
// RtfCompressedToRtf.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A filter to decompress a compressed RTF stream.
public class RtfCompressedToRtf: MimeFilterBase {
    private static let dictionaryInitializerText = "{\\rtf1\\ansi\\mac\\deff0\\deftab720{\\fonttbl;}" +
        "{\\f0\\fnil \\froman \\fswiss \\fmodern \\fscript \\fdecor MS Sans SerifSymbolArialTimes New RomanCourier" +
        "{\\colortbl\\red0\\green0\\blue0\r\n\\par \\pard\\plain\\f0\\fs20\\b\\i\\u\\tab\\tx"
    private static let dictionaryInitializer = Array(dictionaryInitializerText.utf8)

    private enum FilterState {
        case compressedSize
        case uncompressedSize
        case magic
        case crc32
        case beginControlRun
        case readControlOffset
        case processControl
        case readLiteral
        case complete
    }

    private var dict = [UInt8](repeating: 0, count: 4096)
    private let crc32 = Crc32()
    private var state: FilterState = .compressedSize
    private var uncompressedSize: Int = 0
    private var compressedSize: Int = 0
    private var dictWriteOffset: Int = 0
    private var dictReadOffset: Int = 0
    private var dictEndOffset: Int = 0
    private var flagCount: UInt8 = 0
    private var flags: UInt8 = 0
    private var checksum: Int = 0
    private var saved: Int = 0
    private var size: Int = 0

    public private(set) var compressionMode: Int = 0

    /// Initialize a new instance of the `RtfCompressedToRtf` class.
    public override init() {
        super.init()
        let initializer = Self.dictionaryInitializer
        dict.replaceSubrange(0..<initializer.count, with: initializer)
        dictWriteOffset = initializer.count
        dictEndOffset = initializer.count
    }

    /// Get a value indicating whether the crc32 is valid.
    public var isValidCrc32: Bool {
        return Int(crc32.checksum) == checksum
    }

    private func tryReadInt32(_ buffer: [UInt8], index: inout Int, endIndex: Int) -> Int? {
        if index == endIndex {
            return nil
        }

        var nread = (saved >> 24) & 0xFF
        saved &= 0x00FFFFFF

        while nread < 4 && index < endIndex {
            saved |= (Int(buffer[index]) << (nread * 8))
            index += 1
            nread += 1
        }

        let value = Int(Int32(truncatingIfNeeded: saved))

        if nread == 4 {
            saved = 0
            return value
        }

        saved |= (nread << 24)
        return nil
    }

    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        let endIndex = startIndex + length
        var index = startIndex

        if state == .compressedSize {
            guard let value = tryReadInt32(input, index: &index, endIndex: endIndex) else {
                outputLength = 0
                outputIndex = 0
                return input
            }
            compressedSize = value - 12
            state = .uncompressedSize
        }

        if state == .uncompressedSize {
            guard let value = tryReadInt32(input, index: &index, endIndex: endIndex) else {
                outputLength = 0
                outputIndex = 0
                return input
            }
            uncompressedSize = value
            state = .magic
        }

        if state == .magic {
            guard let value = tryReadInt32(input, index: &index, endIndex: endIndex) else {
                outputLength = 0
                outputIndex = 0
                return input
            }
            compressionMode = value
            state = .crc32
        }

        if state == .crc32 {
            guard let value = tryReadInt32(input, index: &index, endIndex: endIndex) else {
                outputLength = 0
                outputIndex = 0
                return input
            }
            checksum = value
            state = .beginControlRun
        }

        if compressionMode != RtfCompressionMode.compressed.rawValue {
            crc32.update(input, offset: index, count: endIndex - index)
            outputLength = max(min(endIndex - index, compressedSize - size), 0)
            size += outputLength
            outputIndex = index
            return input
        }

        let extra = abs(uncompressedSize - compressedSize)
        let estimatedSize = (endIndex - index) + extra
        ensureOutputSize(max(estimatedSize, 4096), preserve: false)
        
        outputLength = 0
        outputIndex = 0

        while index < endIndex && state != .complete {
            let value = input[index]
            index += 1
            crc32.update(value)
            size += 1

            switch state {
            case .beginControlRun:
                flags = value
                flagCount = 1
                state = (flags & 0x01) != 0 ? .readControlOffset : .readLiteral
            case .readLiteral:
                ensureOutputSize(outputLength + 1, preserve: true)
                outputBuffer[outputLength] = value
                outputLength += 1
                dict[dictWriteOffset] = value
                dictWriteOffset += 1
                dictEndOffset = max(dictWriteOffset, dictEndOffset)
                dictWriteOffset %= 4096

                if (flagCount % 8) != 0 {
                    flagCount += 1
                    flags >>= 1
                    state = (flags & 0x01) != 0 ? .readControlOffset : .readLiteral
                } else {
                    state = .beginControlRun
                }
            case .readControlOffset:
                dictReadOffset = Int(value)
                state = .processControl
            case .processControl:
                dictReadOffset = (dictReadOffset << 4) | (Int(value) >> 4)
                let controlLength = Int(value & 0x0F) + 2

                if dictReadOffset == dictWriteOffset {
                    state = .complete
                    break
                }

                ensureOutputSize(outputLength + controlLength, preserve: true)
                let controlEnd = dictReadOffset + controlLength
                while dictReadOffset < controlEnd {
                    let v = dict[dictReadOffset % 4096]
                    dictReadOffset += 1
                    outputBuffer[outputLength] = v
                    outputLength += 1
                    dict[dictWriteOffset] = v
                    dictWriteOffset += 1
                    dictEndOffset = max(dictWriteOffset, dictEndOffset)
                    dictWriteOffset %= 4096
                }

                if (flagCount % 8) != 0 {
                    flagCount += 1
                    flags >>= 1
                    state = (flags & 0x01) != 0 ? .readControlOffset : .readLiteral
                } else {
                    state = .beginControlRun
                }
            default:
                break
            }
        }

        return outputBuffer
    }

    public override func reset() {
        let initializer = Self.dictionaryInitializer
        dict.replaceSubrange(0..<initializer.count, with: initializer)
        dictWriteOffset = initializer.count
        dictEndOffset = initializer.count
        state = .compressedSize
        dictReadOffset = 0
        compressedSize = 0
        uncompressedSize = 0
        crc32.reset()
        flagCount = 0
        checksum = 0
        flags = 0
        saved = 0
        size = 0
        compressionMode = RtfCompressionMode.unknown.rawValue
        super.reset()
    }
}