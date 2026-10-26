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
// YEncoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally encodes content using the yEnc encoding.
///
/// The yEncoding is an encoding that is most commonly used with Usenet and
/// is a binary encoding that includes a 32-bit cyclic redundancy check.
///
/// For more information, see [www.yenc.org](http://www.yenc.org).
public final class YEncoder: MimeEncoder {
    private let lineLength: Int
    private var octets: UInt8 = 0
    private var crc: Crc32

    /// Initialize a new instance of the ``YEncoder`` class.
    ///
    /// Creates a new yEnc encoder.
    ///
    /// - Parameter maxLineLength: The line length to use.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if `maxLineLength` is not within the range of `60` to `998`.
    public init(maxLineLength: Int = 128) throws {
        if maxLineLength < 60 || maxLineLength > 998 {
            throw MimeCodingError.lengthOutOfRange
        }
        self.lineLength = maxLineLength
        self.crc = Crc32(initialValue: -1)
        reset()
    }

    /// Initialize a new instance of the ``YEncoder`` class with default settings.
    ///
    /// Creates a new yEnc encoder with a default line length of 128.
    public convenience init() {
        self.init(uncheckedMaxLineLength: 128)
    }

    /// Internal initializer that skips validation. Used for cloning and known-valid defaults.
    private init(uncheckedMaxLineLength: Int) {
        self.lineLength = uncheckedMaxLineLength
        self.crc = Crc32(initialValue: -1)
        reset()
    }

    /// Get the checksum.
    ///
    /// Gets the checksum.
    public var checksum: Int32 {
        crc.checksum
    }

    /// Get the encoding.
    ///
    /// Gets the encoding that the encoder supports.
    public var encoding: ContentEncoding {
        .default
    }

    /// Clone the ``YEncoder`` with its current state.
    ///
    /// Creates a new ``YEncoder`` with exactly the same state as the current encoder.
    ///
    /// - Returns: A new ``YEncoder`` with identical state.
    public func copy() -> any MimeEncoder {
        let copied = YEncoder(uncheckedMaxLineLength: lineLength)
        copied.crc = crc.copy()
        copied.octets = octets
        return copied
    }

    /// Estimate the length of the output.
    ///
    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// - Parameter inputLength: The input length.
    /// - Returns: The estimated output length.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        (inputLength * 2) + (inputLength / lineLength) + 1
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
            var c = input[index]
            index += 1

            _ = crc.update(c)
            c &+= 42

            if c == 0 || c == 0x09 || c == 0x0D || c == 0x0A || c == 0x3D || c == 0x2E {
                output[outIndex] = 0x3D
                output[outIndex + 1] = c &+ 64
                outIndex += 2
                octets &+= 2
            } else {
                output[outIndex] = c
                outIndex += 1
                octets &+= 1
            }

            if Int(octets) >= lineLength {
                output[outIndex] = 0x0A
                outIndex += 1
                octets = 0
            }
        }

        return outIndex
    }

    /// Encode the specified input into the output buffer, flushing any internal buffer state as well.
    ///
    /// Encodes the specified input into the output buffer, flushing any internal state as well.
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
    public func flush(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        var outIndex = 0
        if length > 0 {
            outIndex = try encode(input, startIndex: startIndex, length: length, output: &output)
        }

        if octets > 0 {
            output[outIndex] = 0x0A
            outIndex += 1
            octets = 0
        }

        return outIndex
    }

    /// Reset the encoder.
    ///
    /// Resets the state of the encoder.
    public func reset() {
        crc.reset()
        octets = 0
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
