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
// HexEncoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally encodes content using URI percent-encoding (hex encoding).
///
/// This encoder is primarily used for encoding parameter values according to
/// the rules specified by RFC 2184 and RFC 2231, which define mechanisms for
/// encoding non-ASCII characters in MIME header parameters.
///
/// Bytes that are valid attribute characters (letters, digits, and some punctuation)
/// are passed through unchanged, while all other bytes are encoded as a percent sign
/// followed by two hexadecimal digits (e.g., `%20` for a space).
public final class HexEncoder: MimeEncoder {
    private static let alphabet: [UInt8] = Array("0123456789ABCDEF".utf8)

    /// Initializes a new instance of the ``HexEncoder`` class.
    ///
    /// Creates a new hex encoder.
    public init() {}

    /// The content encoding that this encoder supports.
    ///
    /// Returns ``ContentEncoding/default`` as this is not a standard MIME content transfer encoding.
    public var encoding: ContentEncoding {
        .default
    }

    /// Creates a copy of this encoder with its current state.
    ///
    /// Creates a new ``HexEncoder``. Since the hex encoder is stateless,
    /// the copy is identical to a newly created encoder.
    ///
    /// - Returns: A new ``HexEncoder`` instance.
    public func copy() -> any MimeEncoder {
        HexEncoder()
    }

    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// In the worst case, every input byte needs to be encoded as a percent sign plus
    /// two hex digits, so the maximum output is three times the input length.
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``encode(_:startIndex:length:output:)`` or ``flush(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be encoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        inputLength * 3
    }

    /// Encodes the specified input into the output buffer.
    ///
    /// Encodes the specified input into the output buffer using percent-encoding.
    /// Bytes that are valid attribute characters are passed through unchanged,
    /// while all other bytes are encoded as `%XX` where XX is the hexadecimal value.
    ///
    /// The output buffer should be large enough to hold all the encoded input.
    /// For estimating the size needed for the output buffer, see ``estimateOutputLength(_:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing bytes to encode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to encode from the input buffer.
    ///   - output: The output buffer to write encoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    public func encode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        var outIndex = 0
        let end = startIndex + length
        var index = startIndex

        while index < end {
            let byte = input[index]
            index += 1
            if ByteClassification.isAttr(byte) {
                output[outIndex] = byte
                outIndex += 1
            } else {
                output[outIndex] = 0x25  // '%'
                output[outIndex + 1] = Self.alphabet[Int((byte >> 4) & 0x0F)]
                output[outIndex + 2] = Self.alphabet[Int(byte & 0x0F)]
                outIndex += 3
            }
        }

        return outIndex
    }

    /// Encodes the specified input into the output buffer, flushing any internal buffer state.
    ///
    /// Since the hex encoder is stateless, this method is equivalent to ``encode(_:startIndex:length:output:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing bytes to encode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to encode from the input buffer.
    ///   - output: The output buffer to write encoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    public func flush(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try encode(input, startIndex: startIndex, length: length, output: &output)
    }

    /// Resets the encoder to its initial state.
    ///
    /// Since the hex encoder is stateless, this method does nothing.
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
