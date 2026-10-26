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
// Rfc2047QuotedPrintableEncoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Encodes content using a variation of the quoted-printable encoding
/// that is specifically meant to be used for rfc2047 encoded-word tokens.
///
/// The rfc2047 "Q" encoding is an encoding often used in MIME to encode textual content
/// outside the ASCII range within an rfc2047 encoded-word token in order to ensure that
/// the text remains intact when sent via 7bit transports such as SMTP.
public final class Rfc2047QuotedPrintableEncoder: Rfc2047Encoder {
    private static let hexAlphabet: [UInt8] = Array("0123456789ABCDEF".utf8)
    private let mode: QEncodeMode

    /// Initialize a new instance of the ``Rfc2047QuotedPrintableEncoder`` class.
    ///
    /// Creates a new rfc2047 quoted-printable encoder.
    ///
    /// - Parameter mode: The rfc2047 encoding mode.
    public init(mode: QEncodeMode) {
        self.mode = mode
    }

    /// Get the rfc2047 encoding method.
    ///
    /// Gets the rfc2047 encoding method.
    ///
    /// Rfc2047 encoded-word tokens support two methods of encoding: base64 and quoted-printable.
    /// These encoding methods are represented by `b` (or `B`) and `q` (or `Q`), respectively.
    public var encoding: Character {
        "q"
    }

    /// Estimate the length of the output.
    ///
    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// - Parameter inputLength: The input length.
    /// - Returns: The estimated output length.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        inputLength * 3
    }

    /// Encode the specified input into the output buffer.
    ///
    /// Encodes the specified input into the output buffer.
    ///
    /// The output buffer should be large enough to hold all the encoded input. For estimating the size needed for the output buffer, see ``estimateOutputLength(_:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer.
    ///   - output: The output buffer.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if `startIndex` and `length` do not specify a valid range in the `input` array.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if `startIndex` and `length` do not specify a valid range in the `input` array.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if `output` is not large enough to contain the encoded content. Use the ``estimateOutputLength(_:)`` method to properly determine the necessary length of the `output` array.
    public func encode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        var outIndex = 0
        let end = startIndex + length
        var index = startIndex

        while index < end {
            let c = input[index]
            index += 1

            if c == 0x20 {
                output[outIndex] = 0x5F
                outIndex += 1
            } else if isSafe(c) {
                output[outIndex] = c
                outIndex += 1
            } else {
                output[outIndex] = 0x3D
                output[outIndex + 1] = Self.hexAlphabet[Int((c >> 4) & 0x0F)]
                output[outIndex + 2] = Self.hexAlphabet[Int(c & 0x0F)]
                outIndex += 3
            }
        }

        return outIndex
    }

    private func isSafe(_ byte: UInt8) -> Bool {
        switch mode {
        case .phrase:
            return ByteClassification.isEncodedPhraseSafe(byte)
        case .text:
            return ByteClassification.isEncodedWordSafe(byte)
        }
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
