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
// TrailingWhitespaceFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A filter for stripping trailing whitespace from lines in a textual stream.
///
/// ``TrailingWhitespaceFilter`` removes spaces and tabs that appear at the end of lines,
/// just before line break characters (`\r` or `\n`). This is useful for cleaning up text
/// files and ensuring consistent formatting.
///
/// ## Overview
///
/// This filter is useful when:
/// - Cleaning up text files with inconsistent whitespace
/// - Preparing content for systems that are sensitive to trailing whitespace
/// - Normalizing text before cryptographic signing
///
/// The filter buffers whitespace characters (spaces and tabs) and only outputs them
/// if they are followed by non-whitespace content on the same line.
///
/// ## Example Usage
///
/// ```swift
/// let filter = TrailingWhitespaceFilter()
/// let input = "Hello   \nWorld\t\n".utf8.map { UInt8($0) }
/// var outputIndex = 0
/// var outputLength = 0
/// let output = filter.filter(input, startIndex: 0, length: input.count,
///                            outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
/// // Result: "Hello\nWorld\n" (trailing whitespace removed)
/// ```
public final class TrailingWhitespaceFilter: MimeFilterBase {
    private var pending: [UInt8] = []

    /// Filters the specified input, removing trailing whitespace from lines.
    ///
    /// This method processes the input buffer and removes any spaces or tabs that appear
    /// at the end of lines (before `\r` or `\n` characters). Whitespace in the middle of
    /// lines is preserved.
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
        if length == 0 {
            if flush {
                pending.removeAll(keepingCapacity: true)
            }
            outputIndex = startIndex
            outputLength = length
            return input
        }

        ensureOutputSize(length + pending.count, preserve: false)
        var out = output
        var outIndex = 0

        for byte in input[startIndex..<(startIndex + length)] {
            if byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") {
                pending.append(byte)
            } else if byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\n") {
                out[outIndex] = byte
                outIndex += 1
                pending.removeAll(keepingCapacity: true)
            } else {
                if !pending.isEmpty {
                    out.replaceSubrange(outIndex..<(outIndex + pending.count), with: pending)
                    outIndex += pending.count
                    pending.removeAll(keepingCapacity: true)
                }
                out[outIndex] = byte
                outIndex += 1
            }
        }

        outputIndex = 0
        outputLength = outIndex
        if flush {
            pending.removeAll(keepingCapacity: true)
        }
        return out
    }

    /// Resets the filter state.
    ///
    /// Clears any pending whitespace that was buffered.
    public override func reset() {
        pending.removeAll(keepingCapacity: true)
        super.reset()
    }
}
