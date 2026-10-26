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
// PassThroughDecoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A pass-through decoder implementing the ``MimeDecoder`` protocol.
///
/// Simply copies data as-is from the input buffer into the output buffer.
public final class PassThroughDecoder: MimeDecoder {
    private let passthroughEncoding: ContentEncoding

    /// Initialize a new instance of the ``PassThroughDecoder`` class.
    ///
    /// Creates a new pass-through decoder.
    ///
    /// - Parameter encoding: The encoding to return in the ``encoding`` property.
    public init(encoding: ContentEncoding) {
        self.passthroughEncoding = encoding
    }

    /// Get the encoding.
    ///
    /// Gets the encoding that the decoder supports.
    public var encoding: ContentEncoding {
        passthroughEncoding
    }

    /// Clone the ``PassThroughDecoder`` with its current state.
    ///
    /// Creates a new ``PassThroughDecoder`` with exactly the same state as the current decoder.
    ///
    /// - Returns: A new ``PassThroughDecoder`` with identical state.
    public func copy() -> any MimeDecoder {
        PassThroughDecoder(encoding: passthroughEncoding)
    }

    /// Estimate the length of the output.
    ///
    /// Estimates the number of bytes needed to decode the specified number of input bytes.
    ///
    /// - Parameter inputLength: The input length.
    /// - Returns: The estimated output length.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        inputLength
    }

    /// Decode the specified input into the output buffer.
    ///
    /// Copies the input buffer into the output buffer, verbatim.
    ///
    /// - Parameters:
    ///   - input: The input buffer.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer.
    ///   - output: The output buffer.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if `startIndex` and `length` do not specify a valid range in the `input` array.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if `startIndex` and `length` do not specify a valid range in the `input` array.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if `output` is not large enough to contain the decoded content. Use the ``estimateOutputLength(_:)`` method to properly determine the necessary length of the `output` array.
    public func decode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        if length > 0 {
            let slice = input[startIndex..<(startIndex + length)]
            output.replaceSubrange(0..<length, with: slice)
        }

        return length
    }

    /// Reset the decoder.
    ///
    /// Resets the state of the decoder.
    public func reset() {}

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count {
            throw MimeCodingError.startIndexOutOfRange
        }
        if length < 0 || length > (input.count - startIndex) {
            throw MimeCodingError.lengthOutOfRange
        }
        if output.count < estimateOutputLength(length) {
            throw MimeCodingError.outputTooSmall
        }
    }
}
