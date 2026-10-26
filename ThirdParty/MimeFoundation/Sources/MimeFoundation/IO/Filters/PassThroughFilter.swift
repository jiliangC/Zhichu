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
// PassThroughFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A filter that simply passes data through without any processing.
///
/// ``PassThroughFilter`` implements the ``MimeFilter`` protocol but performs no
/// transformations on the input data. It can be useful as a placeholder or for
/// testing filter chains.
///
/// ## Overview
///
/// This filter is useful for:
/// - Placeholder filters in filter chains that may be dynamically configured
/// - Testing and debugging filter pipeline infrastructure
/// - Baseline performance measurements of filter overhead
///
/// ## Example Usage
///
/// ```swift
/// let filter = PassThroughFilter()
/// let input: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"
/// var outputIndex = 0
/// var outputLength = 0
/// let output = filter.filter(input, startIndex: 0, length: input.count,
///                            outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
/// // output === input (same reference and content)
/// ```
public final class PassThroughFilter: MimeFilterBase {
    /// Filters the specified input by passing it through unchanged.
    ///
    /// This method simply returns the input buffer without any modifications,
    /// setting the output parameters to indicate the entire input should be
    /// used as output.
    ///
    /// - Parameters:
    ///   - input: The input buffer.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: When this method returns, contains the starting index of the output (equal to `startIndex`).
    ///   - outputLength: When this method returns, contains the length of the output (equal to `length`).
    ///   - flush: If `true`, all internally buffered data should be flushed to the output buffer.
    ///
    /// - Returns: The input buffer, unmodified.
    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        outputIndex = startIndex
        outputLength = length
        return input
    }
}
