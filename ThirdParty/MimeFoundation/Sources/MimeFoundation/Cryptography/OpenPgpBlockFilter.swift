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
// OpenPgpBlockFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

final class OpenPgpBlockFilter: MimeFilterBase {
    private let beginMarker: [UInt8]
    private let endMarker: [UInt8]
    private var seenBeginMarker = false
    private var seenEndMarker = false
    private var midline = false

    init(_ beginMarker: String, _ endMarker: String) {
        self.beginMarker = CharsetUtils.getBytes(beginMarker, encoding: .utf8)
        self.endMarker = CharsetUtils.getBytes(endMarker, encoding: .utf8)
        super.init()
    }

    override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        let endIndex = startIndex + length
        var index = startIndex

        outputIndex = startIndex
        outputLength = 0

        if seenEndMarker || length == 0 {
            return input
        }

        if midline {
            while index < endIndex && input[index] != UInt8(ascii: "\n") {
                index += 1
            }
            if index == endIndex {
                if seenBeginMarker {
                    outputLength = index - startIndex
                }
                return input
            }
            midline = false
        }

        if !seenBeginMarker {
            while index < endIndex {
                let lineIndex = index
                while index < endIndex && input[index] != UInt8(ascii: "\n") {
                    index += 1
                }
                if index == endIndex {
                    if isPartialMatch(input, startIndex: lineIndex, endIndex: index, marker: beginMarker) {
                        saveRemainingInput(input, startIndex: lineIndex, length: index - lineIndex)
                    } else {
                        midline = true
                    }
                    return input
                }

                index += 1

                if isMarker(input, startIndex: lineIndex, marker: beginMarker) {
                    outputLength = index - lineIndex
                    outputIndex = lineIndex
                    seenBeginMarker = true
                    break
                }
            }

            if index == endIndex {
                return input
            }
        }

        while index < endIndex {
            let lineIndex = index
            while index < endIndex && input[index] != UInt8(ascii: "\n") {
                index += 1
            }
            if index == endIndex {
                if !flush {
                    if isPartialMatch(input, startIndex: lineIndex, endIndex: index, marker: endMarker) {
                        saveRemainingInput(input, startIndex: lineIndex, length: index - lineIndex)
                        outputLength = lineIndex - outputIndex
                    } else {
                        outputLength = index - outputIndex
                        midline = true
                    }
                    return input
                }
                outputLength = index - outputIndex
                return input
            }

            index += 1

            if isMarker(input, startIndex: lineIndex, marker: endMarker) {
                seenEndMarker = true
                break
            }
        }

        outputLength = index - outputIndex
        return input
    }

    override func reset() {
        seenBeginMarker = false
        seenEndMarker = false
        midline = false
        super.reset()
    }

    private func isMarker(_ input: [UInt8], startIndex: Int, marker: [UInt8]) -> Bool {
        var i = startIndex
        var j = 0
        while j < marker.count {
            if i >= input.count || input[i] != marker[j] {
                return false
            }
            i += 1
            j += 1
        }
        if i < input.count, input[i] == UInt8(ascii: "\r") {
            i += 1
        }
        return i < input.count && input[i] == UInt8(ascii: "\n")
    }

    private func isPartialMatch(_ input: [UInt8], startIndex: Int, endIndex: Int, marker: [UInt8]) -> Bool {
        var i = startIndex
        var j = 0
        while j < marker.count && i < endIndex {
            if input[i] != marker[j] {
                return false
            }
            i += 1
            j += 1
        }
        if i < endIndex && input[i] == UInt8(ascii: "\r") {
            i += 1
        }
        return i == endIndex
    }
}
