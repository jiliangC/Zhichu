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
// DkimSimpleBodyFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

final class DkimSimpleBodyFilter: DkimBodyFilter {
    override init() {
        super.init()
        lastWasNewLine = false
        isEmptyLine = true
        emptyLines = 0
    }

    override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        let need = length + emptyLines * 2 + 1
        ensureOutputSize(need, preserve: false)
        var output = output
        outputLength = filter(input[startIndex..<(startIndex + length)], output: &output)
        outputIndex = 0
        return output
    }

    override func reset() {
        lastWasNewLine = false
        isEmptyLine = true
        emptyLines = 0
        super.reset()
    }

    private func filter(_ input: ArraySlice<UInt8>, output: inout [UInt8]) -> Int {
        var count = 0
        var outputIndex = 0

        for c in input {
            if c == UInt8(ascii: "\r") {
                if !isEmptyLine {
                    output[outputIndex] = c
                    outputIndex += 1
                    count += 1
                }
            } else if c == UInt8(ascii: "\n") {
                if !isEmptyLine {
                    output[outputIndex] = c
                    outputIndex += 1
                    lastWasNewLine = true
                    isEmptyLine = true
                    emptyLines = 0
                    count += 1
                } else {
                    emptyLines += 1
                }
            } else {
                if emptyLines > 0 {
                    while emptyLines > 0 {
                        output[outputIndex] = UInt8(ascii: "\r")
                        outputIndex += 1
                        output[outputIndex] = UInt8(ascii: "\n")
                        outputIndex += 1
                        emptyLines -= 1
                        count += 2
                    }
                }

                lastWasNewLine = false
                isEmptyLine = false

                output[outputIndex] = c
                outputIndex += 1
                count += 1
            }
        }

        return count
    }
}
