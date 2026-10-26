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
// ArmoredFromFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A filter that armors lines beginning with "From " by encoding the 'F' with
/// Quoted-Printable encoding.
///
/// From-armoring serves a similar purpose as the ``MboxFromFilter``, but uses
/// quoted-printable encoding to replace lines beginning with "From " using "=46rom "
/// instead of replacing those lines with ">From " (which is irreversible).
///
/// ## Overview
///
/// From-armoring is a better alternative to using the ``MboxFromFilter``, but also
/// requires the content transfer encoding property of the MIME part containing the
/// content modified by this filter to be set to Quoted-Printable in order to work
/// properly.
///
/// This armoring technique ensures that the receiving client will still be able to
/// verify PGP/MIME and S/MIME signatures.
///
/// ## Example Usage
///
/// ```swift
/// let filter = ArmoredFromFilter()
/// let input = "From someone@example.com".utf8.map { UInt8($0) }
/// var outputIndex = 0
/// var outputLength = 0
/// let output = filter.filter(input, startIndex: 0, length: input.count,
///                            outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
/// // Result: "=46rom someone@example.com"
/// ```
public final class ArmoredFromFilter: MimeFilterBase {
    private static let marker = Array("From ".utf8)
    private var midline = false

    /// Filters the specified input, encoding 'F' in lines beginning with "From " using Quoted-Printable.
    ///
    /// This method processes the input buffer and identifies lines that start with "From ".
    /// For each such line found, the 'F' character is replaced with "=46" (the Quoted-Printable
    /// encoding of 'F'), resulting in "=46rom ".
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
                if next >= ArmoredFromFilter.marker.count {
                    if slice.starts(with: ArmoredFromFilter.marker) {
                        fromOffsets.append(index)
                    }
                }
                index += next + 1
            } else {
                if slice.count >= ArmoredFromFilter.marker.count {
                    if slice.starts(with: ArmoredFromFilter.marker) {
                        fromOffsets.append(index)
                    }
                } else if !flush, slice.elementsEqual(ArmoredFromFilter.marker.prefix(slice.count)) {
                    saveRemainingInput(input, startIndex: startIndex + index, length: slice.count)
                    endIndex = index
                    break
                }
                midline = true
                break
            }
        }

        if !fromOffsets.isEmpty {
            let need = endIndex + fromOffsets.count * 2
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
                output[outputLength] = UInt8(ascii: "=")
                output[outputLength + 1] = UInt8(ascii: "4")
                output[outputLength + 2] = UInt8(ascii: "6")
                outputLength += 3
                index += 1
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
