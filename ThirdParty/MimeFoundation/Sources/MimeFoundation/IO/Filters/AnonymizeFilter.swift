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
// AnonymizeFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A filter for anonymizing content.
///
/// ``AnonymizeFilter`` replaces all non-whitespace characters with an 'x',
/// effectively anonymizing text content while preserving its structure
/// and whitespace patterns.
///
/// ## Overview
///
/// This filter is useful for:
/// - Creating sanitized log files that preserve structure but hide sensitive data
/// - Testing email parsing with realistic message structures
/// - Debugging message formats while protecting confidential information
///
/// ## Example Usage
///
/// ```swift
/// let filter = AnonymizeFilter()
/// let input = "Hello, World!".utf8.map { UInt8($0) }
/// var outputIndex = 0
/// var outputLength = 0
/// let output = filter.filter(input, startIndex: 0, length: input.count,
///                            outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
/// // Result: "xxxxx, xxxxxx!"
/// ```
public final class AnonymizeFilter: MimeFilterBase {
    /// Filters the specified input, replacing all non-whitespace characters with 'x'.
    ///
    /// This method processes the input buffer and creates output where every non-whitespace
    /// byte is replaced with the character 'x', while preserving all whitespace characters
    /// (spaces, tabs, newlines, etc.) in their original positions.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to anonymize.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: When this method returns, contains the starting index of the output in the returned buffer.
    ///   - outputLength: When this method returns, contains the length of the output buffer.
    ///   - flush: If `true`, all internally buffered data should be flushed to the output buffer.
    ///
    /// - Returns: The filtered output buffer.
    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        ensureOutputSize(length, preserve: false)
        var output = self.output
        outputIndex = 0

        let endIndex = startIndex + length
        var index = startIndex
        var outIndex = 0
        while index < endIndex {
            let byte = input[index]
            output[outIndex] = ByteClassification.isWhitespace(byte) ? byte : UInt8(ascii: "x")
            outIndex += 1
            index += 1
        }

        outputLength = outIndex
        return output
    }
}
