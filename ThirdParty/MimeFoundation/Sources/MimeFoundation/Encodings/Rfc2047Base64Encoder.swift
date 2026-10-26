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
// Rfc2047Base64Encoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A base64 encoder that is specifically meant to be used for rfc2047 encoded-word tokens.
///
/// The rfc2047 "B" encoding is an encoding often used in MIME to encode textual content outside
/// the ASCII range within an rfc2047 encoded-word token in order to ensure that the text remains
/// intact when sent via 7bit transports such as SMTP.
public final class Rfc2047Base64Encoder: Rfc2047Encoder {
    private static let alphabet: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    /// Initialize a new instance of the ``Rfc2047Base64Encoder`` class.
    ///
    /// Creates a new rfc2047 base64 encoder.
    public init() {}

    /// Get the rfc2047 encoding method.
    ///
    /// Gets the rfc2047 encoding method.
    ///
    /// Rfc2047 encoded-word tokens support two methods of encoding: base64 and quoted-printable.
    /// These encoding methods are represented by `b` (or `B`) and `q` (or `Q`), respectively.
    public var encoding: Character {
        "b"
    }

    /// Estimate the length of the output.
    ///
    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// - Parameter inputLength: The input length.
    /// - Returns: The estimated output length.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        ((inputLength + 2) / 3) * 4
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
        var index = startIndex
        let end = startIndex + length

        while index + 2 < end {
            let c1 = input[index]
            let c2 = input[index + 1]
            let c3 = input[index + 2]
            index += 3

            output[outIndex] = Self.alphabet[Int(c1 >> 2)]
            output[outIndex + 1] = Self.alphabet[Int((c2 >> 4) | ((c1 & 0x03) << 4))]
            output[outIndex + 2] = Self.alphabet[Int(((c2 & 0x0F) << 2) | (c3 >> 6))]
            output[outIndex + 3] = Self.alphabet[Int(c3 & 0x3F)]
            outIndex += 4
        }

        let remaining = end - index
        if remaining == 2 {
            let c1 = input[index]
            let c2 = input[index + 1]
            output[outIndex] = Self.alphabet[Int(c1 >> 2)]
            output[outIndex + 1] = Self.alphabet[Int((c2 >> 4) | ((c1 & 0x03) << 4))]
            output[outIndex + 2] = Self.alphabet[Int((c2 & 0x0F) << 2)]
            output[outIndex + 3] = 0x3D
            outIndex += 4
        } else if remaining == 1 {
            let c1 = input[index]
            output[outIndex] = Self.alphabet[Int(c1 >> 2)]
            output[outIndex + 1] = Self.alphabet[Int((c1 & 0x03) << 4)]
            output[outIndex + 2] = 0x3D
            output[outIndex + 3] = 0x3D
            outIndex += 4
        }

        return outIndex
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
