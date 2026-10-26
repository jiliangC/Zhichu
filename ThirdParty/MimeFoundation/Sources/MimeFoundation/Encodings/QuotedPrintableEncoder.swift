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
// QuotedPrintableEncoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally encodes content using the Quoted-Printable encoding.
///
/// Quoted-Printable is an encoding often used in MIME to encode textual content
/// outside the ASCII range in order to ensure that the text remains intact
/// when sent via 7-bit transports such as SMTP.
///
/// The Quoted-Printable encoding represents non-printable or non-ASCII characters
/// as an equals sign followed by two hexadecimal digits (e.g., `=3D` for the equals sign itself).
/// This encoding is particularly efficient for text that is mostly ASCII, as ASCII characters
/// are passed through unchanged.
public final class QuotedPrintableEncoder: MimeEncoder {
    private static let hexAlphabet: [UInt8] = Array("0123456789ABCDEF".utf8)

    private let tripletsPerLine: Int
    private let maxLineLength: Int
    private var currentLineLength: Int = 0
    private var saved: Int = -1

    /// Initializes a new instance of the ``QuotedPrintableEncoder`` class with the default maximum line length of 76 characters.
    ///
    /// Creates a new Quoted-Printable encoder that wraps output lines at 76 characters,
    /// which is the maximum line length allowed by RFC 2045 for Quoted-Printable encoding.
    public convenience init() {
        self.init(uncheckedMaxLineLength: 76)
    }

    /// Initializes a new instance of the ``QuotedPrintableEncoder`` class with the specified maximum line length.
    ///
    /// Creates a new Quoted-Printable encoder. The maximum line length will be capped at 76 characters
    /// as required by RFC 2045, even if a larger value is specified.
    ///
    /// - Parameter maxLineLength: The maximum number of octets allowed per line (not counting the newline character).
    ///   Must be between ``FormatOptions/minimumLineLength`` (60) and ``FormatOptions/maximumLineLength`` (998), inclusive.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the maximum line length is not within the valid range.
    public init(maxLineLength: Int) throws {
        if maxLineLength < FormatOptions.minimumLineLength || maxLineLength > FormatOptions.maximumLineLength {
            throw MimeCodingError.lengthOutOfRange
        }

        // The quoted-printable specification in RFC 2045 requires a maximum line length of 76.
        let normalized = min(maxLineLength, 76)
        self.tripletsPerLine = normalized / 3
        self.maxLineLength = normalized
        reset()
    }

    /// Internal initializer that skips validation. Used for default init.
    private init(uncheckedMaxLineLength: Int) {
        let normalized = min(uncheckedMaxLineLength, 76)
        self.tripletsPerLine = normalized / 3
        self.maxLineLength = normalized
        reset()
    }

    private init(tripletsPerLine: Int, maxLineLength: Int, currentLineLength: Int, saved: Int) {
        self.tripletsPerLine = tripletsPerLine
        self.maxLineLength = maxLineLength
        self.currentLineLength = currentLineLength
        self.saved = saved
    }

    /// The content encoding that this encoder supports.
    ///
    /// Always returns ``ContentEncoding/quotedPrintable`` for this encoder.
    public var encoding: ContentEncoding {
        .quotedPrintable
    }

    /// Creates a copy of this encoder with its current state.
    ///
    /// Creates a new ``QuotedPrintableEncoder`` with exactly the same state as the current encoder,
    /// including any buffered input byte and the current line position. This allows the
    /// encoding process to be forked or saved at a particular point.
    ///
    /// - Returns: A new ``QuotedPrintableEncoder`` with identical state.
    public func copy() -> any MimeEncoder {
        QuotedPrintableEncoder(tripletsPerLine: tripletsPerLine,
                               maxLineLength: maxLineLength,
                               currentLineLength: currentLineLength,
                               saved: saved)
    }

    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// This method calculates the maximum possible output size, accounting for the worst-case
    /// scenario where every byte needs to be encoded as a triplet (equals sign plus two hex digits).
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``encode(_:startIndex:length:output:)`` or ``flush(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be encoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        var length = inputLength
        if saved != -1 {
            length += 1
        }
        return ((length / tripletsPerLine) * (maxLineLength + 1)) + ((length % tripletsPerLine) * 3) + 2
    }

    /// Encodes the specified input into the output buffer.
    ///
    /// Encodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the encoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// The encoder buffers the last byte internally to properly handle line endings and trailing
    /// whitespace, which must be encoded according to the Quoted-Printable specification.
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

        while index < end {
            let c = input[index]
            index += 1

            if c == 0x0D {
                if saved != -1 {
                    let b = UInt8(saved)
                    if ByteClassification.isBlank(b) || !ByteClassification.isQpSafe(b) {
                        output[outIndex] = 0x3D
                        output[outIndex + 1] = Self.hexAlphabet[Int((b >> 4) & 0x0F)]
                        output[outIndex + 2] = Self.hexAlphabet[Int(b & 0x0F)]
                        outIndex += 3
                        currentLineLength += 3
                    } else {
                        output[outIndex] = b
                        outIndex += 1
                        currentLineLength += 1
                    }
                }
                saved = Int(c)
            } else if c == 0x0A {
                if saved != -1 && saved != 0x0D {
                    let b = UInt8(saved)
                    if ByteClassification.isBlank(b) || !ByteClassification.isQpSafe(b) {
                        output[outIndex] = 0x3D
                        output[outIndex + 1] = Self.hexAlphabet[Int((b >> 4) & 0x0F)]
                        output[outIndex + 2] = Self.hexAlphabet[Int(b & 0x0F)]
                        outIndex += 3
                    } else {
                        output[outIndex] = b
                        outIndex += 1
                    }
                }

                output[outIndex] = 0x0A
                outIndex += 1
                currentLineLength = 0
                saved = -1
            } else {
                if saved != -1 {
                    let b = UInt8(saved)
                    if ByteClassification.isQpSafe(b) {
                        output[outIndex] = b
                        outIndex += 1
                        currentLineLength += 1
                    } else {
                        output[outIndex] = 0x3D
                        output[outIndex + 1] = Self.hexAlphabet[Int((b >> 4) & 0x0F)]
                        output[outIndex + 2] = Self.hexAlphabet[Int(b & 0x0F)]
                        outIndex += 3
                        currentLineLength += 3
                    }

                    if currentLineLength + 1 >= maxLineLength {
                        output[outIndex] = 0x3D
                        output[outIndex + 1] = 0x0A
                        outIndex += 2
                        currentLineLength = 0
                    }
                }
                saved = Int(c)
            }
        }

        return outIndex
    }

    /// Encodes the specified input into the output buffer, flushing any internal buffer state.
    ///
    /// Encodes the specified input into the output buffer, flushing any internal state as well.
    /// This method should be called when encoding the final chunk of data to ensure all
    /// buffered content is written to the output.
    ///
    /// The output ends with a soft line break (`=\n`) to ensure that any trailing content
    /// is not misinterpreted when decoded.
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

        if saved != -1 {
            let c = UInt8(saved)
            // Spaces and tabs must be encoded if they are the last character on the line
            if ByteClassification.isBlank(c) || !ByteClassification.isQpSafe(c) {
                output[outIndex] = 0x3D
                output[outIndex + 1] = Self.hexAlphabet[Int((c >> 4) & 0x0F)]
                output[outIndex + 2] = Self.hexAlphabet[Int(c & 0x0F)]
                outIndex += 3
            } else {
                output[outIndex] = c
                outIndex += 1
            }
            // We end with =\n so that the \n isn't interpreted as a real \n when it gets decoded later
            output[outIndex] = 0x3D
            output[outIndex + 1] = 0x0A
            outIndex += 2
        }

        reset()
        return outIndex
    }

    /// Resets the encoder to its initial state.
    ///
    /// Resets the internal state of the encoder, clearing any buffered input byte
    /// and resetting the line position. After calling this method, the encoder can
    /// be reused to encode new content from the beginning.
    public func reset() {
        currentLineLength = 0
        saved = -1
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
