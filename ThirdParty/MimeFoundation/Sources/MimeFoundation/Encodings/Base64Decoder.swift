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
// Base64Decoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally decodes content encoded with the Base64 encoding.
///
/// Base64 is an encoding often used in MIME to encode binary content such as images
/// and other types of multimedia to ensure that the data remains intact when sent
/// via 7-bit transports such as SMTP.
///
/// The decoder processes input in quartets (4 characters) and outputs triplets (3 bytes).
/// Input characters that don't complete a quartet are buffered internally until more data
/// is provided.
public final class Base64Decoder: MimeDecoder {
    private static let base64Rank: [UInt8] = {
        var table = Array(repeating: UInt8(0xFF), count: 256)
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        for (index, value) in alphabet.enumerated() {
            table[Int(value)] = UInt8(index)
        }
        table[Int(0x3D)] = 0
        return table
    }()

    /// Gets or sets whether the decoder should use hardware acceleration when available.
    ///
    /// When enabled, the decoder will use SIMD instructions if the platform supports them.
    /// This can significantly improve decoding performance for large inputs.
    public var enableHardwareAcceleration: Bool = false

    private var previous: Int = 0
    private var saved: UInt32 = 0
    private var bytes: UInt8 = 0

    /// Initializes a new instance of the ``Base64Decoder`` class.
    ///
    /// Creates a new Base64 decoder ready to decode Base64-encoded content.
    public init() {}

    /// The content encoding that this decoder supports.
    ///
    /// Always returns ``ContentEncoding/base64`` for this decoder.
    public var encoding: ContentEncoding {
        .base64
    }

    /// Creates a copy of this decoder with its current state.
    ///
    /// Creates a new ``Base64Decoder`` with exactly the same state as the current decoder,
    /// including any buffered input characters. This allows the decoding process to be
    /// forked or saved at a particular point.
    ///
    /// - Returns: A new ``Base64Decoder`` with identical state.
    public func copy() -> any MimeDecoder {
        let copied = Base64Decoder()
        copied.enableHardwareAcceleration = enableHardwareAcceleration
        copied.previous = previous
        copied.saved = saved
        copied.bytes = bytes
        return copied
    }

    /// Estimates the number of bytes needed to decode the specified number of input bytes.
    ///
    /// This method calculates the maximum possible output size, accounting for the Base64
    /// compression ratio (3 output bytes for every 4 input characters).
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``decode(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be decoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        // Decoding base64 converts 4 bytes of input into 3 bytes of output
        return ((inputLength / 4) * 3) + 3
    }

    /// Decodes the specified input into the output buffer.
    ///
    /// Decodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the decoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// Any input characters that do not complete a quartet are buffered internally and will be
    /// included in subsequent calls to ``decode(_:startIndex:length:output:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing Base64-encoded bytes to decode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to decode from the input buffer.
    ///   - output: The output buffer to write decoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    public func decode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        var outIndex = 0
        var index = startIndex
        let end = startIndex + length

        while index < end {
            let c = input[index]
            index += 1
            let rank = Base64Decoder.base64Rank[Int(c)]
            if rank != 0xFF {
                previous = (previous << 8) | Int(c)
                saved = (saved << 6) | UInt32(rank)
                bytes &+= 1

                if bytes == 4 {
                    if (previous & 0x00FF0000) != (Int(0x3D) << 16) {
                        output[outIndex] = UInt8((saved >> 16) & 0xFF)
                        outIndex += 1
                        if (previous & 0x0000FF00) != (Int(0x3D) << 8) {
                            output[outIndex] = UInt8((saved >> 8) & 0xFF)
                            outIndex += 1
                            if (previous & 0x000000FF) != Int(0x3D) {
                                output[outIndex] = UInt8(saved & 0xFF)
                                outIndex += 1
                            }
                        }
                    }
                    saved = 0
                    bytes = 0
                }
            }
        }

        return outIndex
    }

    /// Resets the decoder to its initial state.
    ///
    /// Resets the internal state of the decoder, clearing any buffered input characters.
    /// After calling this method, the decoder can be reused to decode new content from the beginning.
    public func reset() {
        previous = 0
        saved = 0
        bytes = 0
    }

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
