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
// MboxFromFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A filter that munges lines beginning with "From " by stuffing a '>' into the beginning of the line.
///
/// Munging Mbox-style "From "-lines is a workaround to prevent Mbox parsers from misinterpreting a
/// line beginning with "From " as an mbox marker delineating messages. This munging is non-reversible but
/// is necessary to properly format a message for saving to an Mbox file.
///
/// ## Overview
///
/// The mbox format uses lines beginning with "From " to separate individual messages in a mailbox file.
/// When message content contains lines that begin with "From ", these must be "munged" by prepending
/// a '>' character to prevent them from being interpreted as message separators.
///
/// ## Example Usage
///
/// ```swift
/// let filter = MboxFromFilter()
/// let input = "From someone@example.com\nHello".utf8.map { UInt8($0) }
/// var outputIndex = 0
/// var outputLength = 0
/// let output = filter.filter(input, startIndex: 0, length: input.count,
///                            outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
/// // Result: ">From someone@example.com\nHello"
/// ```
public final class MboxFromFilter: MimeFilterBase {
    private static let marker = Array("From ".utf8)
    private var midline = false

    /// Filters the specified input, prepending '>' to lines beginning with "From ".
    ///
    /// This method processes the input buffer and identifies lines that start with "From ".
    /// For each such line found, a '>' character is inserted at the beginning to prevent
    /// mbox parsers from misinterpreting them as message boundaries.
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
        let span = Array(input[startIndex..<(startIndex + length)])
        var fromOffsets: [Int] = []
        var endIndex = length
        var index = 0

        if midline {
            if let next = span[index...].firstIndex(of: UInt8(ascii: "\n")) {
                index = next - span.startIndex + 1
                midline = false
            } else {
                index = length
            }
        }

        while index < length {
            let slice = Array(span[index..<length])
            if let next = slice.firstIndex(of: UInt8(ascii: "\n")) {
                if next >= MboxFromFilter.marker.count {
                    if slice.starts(with: MboxFromFilter.marker) {
                        fromOffsets.append(index)
                    }
                }
                index += next + 1
            } else {
                if slice.count >= MboxFromFilter.marker.count {
                    if slice.starts(with: MboxFromFilter.marker) {
                        fromOffsets.append(index)
                    }
                } else if !flush, slice.elementsEqual(MboxFromFilter.marker.prefix(slice.count)) {
                    saveRemainingInput(input, startIndex: startIndex + index, length: slice.count)
                    endIndex = index
                    break
                }
                midline = true
                break
            }
        }

        if !fromOffsets.isEmpty {
            let need = endIndex + fromOffsets.count
            ensureOutputSize(need, preserve: false)
            var output = output
            outputLength = 0
            outputIndex = 0
            index = 0

            for offset in fromOffsets {
                if index < offset {
                    let src = span[index..<offset]
                    output.replaceSubrange(outputLength..<(outputLength + src.count), with: src)
                    outputLength += src.count
                    index = offset
                }
                output[outputLength] = UInt8(ascii: ">")
                outputLength += 1
            }

            if index < endIndex {
                let src = span[index..<endIndex]
                output.replaceSubrange(outputLength..<(outputLength + src.count), with: src)
                outputLength += src.count
            }
            return output
        }

        outputIndex = startIndex
        outputLength = endIndex
        return input
    }

    /// Resets the filter state.
    ///
    /// Resets the filter to its initial state, clearing any internal tracking
    /// of whether the filter is currently processing a line.
    public override func reset() {
        midline = false
        super.reset()
    }
}
