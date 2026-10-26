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
// Base64Encoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally encodes content using the Base64 encoding.
///
/// Base64 is an encoding often used in MIME to encode binary content such as images
/// and other types of multimedia to ensure that the data remains intact when sent
/// via 7-bit transports such as SMTP.
///
/// The encoder processes input in triplets (3 bytes) and outputs quartets (4 characters).
/// Input bytes that don't complete a triplet are buffered internally until more data
/// is provided or ``flush(_:startIndex:length:output:)`` is called.
public final class Base64Encoder: MimeEncoder {
    private static let alphabet: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    /// Gets or sets whether the encoder should use hardware acceleration when available.
    ///
    /// When enabled, the encoder will use SIMD instructions if the platform supports them.
    /// This can significantly improve encoding performance for large inputs.
    public var enableHardwareAcceleration: Bool = false

    private let quartetsPerLine: Int
    private var quartets: Int = 0
    private var saved1: UInt8 = 0
    private var saved2: UInt8 = 0
    private var saved: Int = 0

    /// Initializes a new instance of the ``Base64Encoder`` class with the default maximum line length of 76 characters.
    ///
    /// Creates a new Base64 encoder that wraps output lines at 76 characters, which is the
    /// standard line length for MIME Base64-encoded content.
    public convenience init() {
        self.init(uncheckedMaxLineLength: 76)
    }

    /// Initializes a new instance of the ``Base64Encoder`` class with the specified maximum line length.
    ///
    /// Creates a new Base64 encoder that wraps output lines at the specified length.
    /// The maximum line length must be between ``FormatOptions/minimumLineLength`` (60) and
    /// ``FormatOptions/maximumLineLength`` (998), inclusive.
    ///
    /// - Parameter maxLineLength: The maximum number of octets allowed per line (not counting the newline character).
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the maximum line length is not within the valid range.
    public init(maxLineLength: Int) throws {
        if maxLineLength < FormatOptions.minimumLineLength || maxLineLength > FormatOptions.maximumLineLength {
            throw MimeCodingError.lengthOutOfRange
        }
        quartetsPerLine = maxLineLength / 4
    }

    /// Internal initializer that skips validation. Used for cloning and known-valid defaults.
    private init(uncheckedMaxLineLength: Int) {
        quartetsPerLine = uncheckedMaxLineLength / 4
    }

    /// The content encoding that this encoder supports.
    ///
    /// Always returns ``ContentEncoding/base64`` for this encoder.
    public var encoding: ContentEncoding {
        .base64
    }

    /// Creates a copy of this encoder with its current state.
    ///
    /// Creates a new ``Base64Encoder`` with exactly the same state as the current encoder,
    /// including any buffered input bytes and the current line position. This allows the
    /// encoding process to be forked or saved at a particular point.
    ///
    /// - Returns: A new ``Base64Encoder`` with identical state.
    public func copy() -> any MimeEncoder {
        let copied = Base64Encoder(uncheckedMaxLineLength: quartetsPerLine * 4)
        copied.enableHardwareAcceleration = enableHardwareAcceleration
        copied.quartets = quartets
        copied.saved1 = saved1
        copied.saved2 = saved2
        copied.saved = saved
        return copied
    }

    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// This method calculates the maximum possible output size, accounting for the Base64
    /// expansion ratio (4 output bytes for every 3 input bytes) plus line breaks.
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``encode(_:startIndex:length:output:)`` or ``flush(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be encoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        let maxLineLength = (quartetsPerLine * 4) + 1
        let maxInputPerLine = quartetsPerLine * 3
        return (((inputLength + 2) / maxInputPerLine) * maxLineLength) + maxLineLength
    }

    /// Encodes the specified input into the output buffer.
    ///
    /// Encodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the encoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// Any input bytes that do not complete a triplet are buffered internally and will be
    /// included in subsequent calls to ``encode(_:startIndex:length:output:)`` or
    /// ``flush(_:startIndex:length:output:)``.
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
        var index = startIndex
        let end = startIndex + length

        func writeQuartet(_ c1: UInt8, _ c2: UInt8, _ c3: UInt8) {
            output[outIndex] = Self.alphabet[Int(c1 >> 2)]
            output[outIndex + 1] = Self.alphabet[Int((c2 >> 4) | ((c1 & 0x03) << 4))]
            output[outIndex + 2] = Self.alphabet[Int(((c2 & 0x0F) << 2) | (c3 >> 6))]
            output[outIndex + 3] = Self.alphabet[Int(c3 & 0x3F)]
            outIndex += 4
            quartets += 1
            if quartets >= quartetsPerLine {
                output[outIndex] = 0x0A
                outIndex += 1
                quartets = 0
            }
        }

        if saved > 0 {
            if saved == 1 {
                if index + 1 < end {
                    let c1 = saved1
                    let c2 = input[index]
                    let c3 = input[index + 1]
                    index += 2
                    saved = 0
                    writeQuartet(c1, c2, c3)
                } else if index < end {
                    saved2 = input[index]
                    saved = 2
                    index += 1
                }
            } else if saved == 2 {
                if index < end {
                    let c1 = saved1
                    let c2 = saved2
                    let c3 = input[index]
                    index += 1
                    saved = 0
                    writeQuartet(c1, c2, c3)
                }
            }
        }

        while index + 2 < end {
            let c1 = input[index]
            let c2 = input[index + 1]
            let c3 = input[index + 2]
            index += 3
            writeQuartet(c1, c2, c3)
        }

        let remaining = end - index
        if remaining == 1 {
            saved1 = input[index]
            saved = 1
        } else if remaining == 2 {
            saved1 = input[index]
            saved2 = input[index + 1]
            saved = 2
        }

        return outIndex
    }

    /// Encodes the specified input into the output buffer, flushing any internal buffer state.
    ///
    /// Encodes the specified input into the output buffer, flushing any internal state as well.
    /// This method should be called when encoding the final chunk of data to ensure all
    /// buffered content is written to the output, including any necessary padding characters.
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
    public func flush(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        var outIndex = 0
        if length > 0 {
            outIndex = try encode(input, startIndex: startIndex, length: length, output: &output)
        }

        if saved >= 1 {
            let c1 = saved1
            let c2 = saved2
            output[outIndex] = Self.alphabet[Int(c1 >> 2)]
            output[outIndex + 1] = Self.alphabet[Int((c2 >> 4) | ((c1 & 0x03) << 4))]
            if saved == 2 {
                output[outIndex + 2] = Self.alphabet[Int((c2 & 0x0F) << 2)]
            } else {
                output[outIndex + 2] = 0x3D
            }
            output[outIndex + 3] = 0x3D
            outIndex += 4
            quartets += 1
            saved = 0
        }

        if quartets > 0 {
            output[outIndex] = 0x0A
            outIndex += 1
            quartets = 0
        }

        return outIndex
    }

    /// Resets the encoder to its initial state.
    ///
    /// Resets the internal state of the encoder, clearing any buffered input bytes
    /// and resetting the line position. After calling this method, the encoder can
    /// be reused to encode new content from the beginning.
    public func reset() {
        quartets = 0
        saved1 = 0
        saved2 = 0
        saved = 0
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
