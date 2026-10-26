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
// Dos2UnixFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A filter that converts from Windows/DOS line endings to Unix line endings.
///
/// ``Dos2UnixFilter`` converts CRLF (Carriage Return + Line Feed, `\r\n`) sequences
/// to LF (Line Feed, `\n`) only, transforming DOS/Windows-style line endings into
/// Unix-style line endings.
///
/// ## Overview
///
/// This filter is useful when:
/// - Processing text files from Windows systems on Unix platforms
/// - Normalizing line endings in MIME content
/// - Converting DOS format files to Unix format
///
/// ## Example Usage
///
/// ```swift
/// let filter = Dos2UnixFilter()
/// let input = "Hello\r\nWorld\r\n".utf8.map { UInt8($0) }
/// var outputIndex = 0
/// var outputLength = 0
/// let output = filter.filter(input, startIndex: 0, length: input.count,
///                            outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
/// // Result: "Hello\nWorld\n"
/// ```
public final class Dos2UnixFilter: MimeFilterBase {
    private let ensureNewLine: Bool
    private var previous: UInt8 = 0

    /// Initializes a new instance of the ``Dos2UnixFilter`` class.
    ///
    /// - Parameter ensureNewLine: If `true`, ensures that the stream ends with a newline character.
    ///   Defaults to `false`.
    public init(_ ensureNewLine: Bool = false) {
        self.ensureNewLine = ensureNewLine
        super.init()
    }

    private func filterBytes(_ input: [UInt8], output: inout [UInt8], flush: Bool) -> Int {
        var outputIndex = 0
        for byte in input {
            if byte == UInt8(ascii: "\n") {
                output[outputIndex] = byte
                outputIndex += 1
            } else {
                if previous == UInt8(ascii: "\r") {
                    output[outputIndex] = previous
                    outputIndex += 1
                }
                if byte != UInt8(ascii: "\r") {
                    output[outputIndex] = byte
                    outputIndex += 1
                }
            }
            previous = byte
        }

        if flush && ensureNewLine && previous != UInt8(ascii: "\n") {
            output[outputIndex] = UInt8(ascii: "\n")
            outputIndex += 1
            previous = UInt8(ascii: "\n")
        }

        return outputIndex
    }

    /// Filters the specified input, converting CRLF line endings to LF.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to filter.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: When this method returns, contains the starting index of the output in the returned buffer.
    ///   - outputLength: When this method returns, contains the length of the output buffer.
    ///   - flush: If `true`, all internally buffered data should be flushed to the output buffer.
    ///
    /// - Returns: The filtered output buffer.
    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        let slice = Array(input[startIndex..<(startIndex + length)])
        let extra = previous == UInt8(ascii: "\r") ? 1 : 0
        ensureOutputSize(length + extra + (flush && ensureNewLine ? 1 : 0), preserve: false)
        var out = output
        outputLength = filterBytes(slice, output: &out, flush: flush)
        outputIndex = 0
        return out
    }

    /// Resets the filter state.
    ///
    /// Clears the internal state tracking the previous character.
    public override func reset() {
        previous = 0
        super.reset()
    }
}
