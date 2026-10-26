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
// UUEncoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally encodes content using the Unix-to-Unix (UUEncode) encoding.
///
/// The UUEncoding is an encoding that predates MIME and was used to encode binary content
/// such as images and other types of multimedia to ensure that the data remained intact
/// when sent via 7-bit transports such as SMTP.
///
/// These days, the UUEncoding has largely been deprecated in favor of the Base64 encoding,
/// however, some older mail clients still use it.
///
/// Each line of UUEncoded output begins with a length character followed by the encoded data.
/// The standard UUEncode format encodes 45 bytes of input into 60 characters of output per line
/// (plus the length character and newline).
public final class UUEncoder: MimeEncoder {
    private static let maxInputPerLine = 45
    private static let maxOutputPerLine = ((maxInputPerLine / 3) * 4) + 2

    private var lineBuffer: [UInt8] = []
    private var savedBytes: [UInt8] = []
    private var uulen: Int = 0

    /// Initializes a new instance of the ``UUEncoder`` class.
    ///
    /// Creates a new Unix-to-Unix encoder.
    public init() {}

    /// The content encoding that this encoder supports.
    ///
    /// Always returns ``ContentEncoding/uuEncode`` for this encoder.
    public var encoding: ContentEncoding {
        .uuEncode
    }

    /// Creates a copy of this encoder with its current state.
    ///
    /// Creates a new ``UUEncoder`` with exactly the same state as the current encoder,
    /// including any buffered input bytes and the current line buffer. This allows the
    /// encoding process to be forked or saved at a particular point.
    ///
    /// - Returns: A new ``UUEncoder`` with identical state.
    public func copy() -> any MimeEncoder {
        let copied = UUEncoder()
        copied.lineBuffer = lineBuffer
        copied.savedBytes = savedBytes
        copied.uulen = uulen
        return copied
    }

    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// This method calculates the maximum possible output size, accounting for the UUEncode
    /// expansion ratio (4 output characters for every 3 input bytes) plus line length characters
    /// and newlines.
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``encode(_:startIndex:length:output:)`` or ``flush(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be encoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        (((inputLength + 2) / UUEncoder.maxInputPerLine) * UUEncoder.maxOutputPerLine) + UUEncoder.maxOutputPerLine + 2
    }

    /// Encodes the specified input into the output buffer.
    ///
    /// Encodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the encoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// Input bytes that don't complete a line (45 bytes) are buffered internally and will be
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
        let end = startIndex + length
        var index = startIndex

        while index < end {
            savedBytes.append(input[index])
            index += 1

            if savedBytes.count == 3 {
                appendEncodedTriplet(savedBytes[0], savedBytes[1], savedBytes[2])
                savedBytes.removeAll(keepingCapacity: true)
                uulen += 3

                if uulen >= UUEncoder.maxInputPerLine {
                    outIndex = flushLine(into: &output, at: outIndex, lengthOverride: uulen)
                }
            }
        }

        return outIndex
    }

    /// Encodes the specified input into the output buffer, flushing any internal buffer state.
    ///
    /// Encodes the specified input into the output buffer, flushing any internal state as well.
    /// This method should be called when encoding the final chunk of data to ensure all
    /// buffered content is written to the output, including the terminating zero-length line.
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

        var uufill = 0
        if !savedBytes.isEmpty {
            while savedBytes.count < 3 {
                savedBytes.append(0)
                uufill += 1
            }
            appendEncodedTriplet(savedBytes[0], savedBytes[1], savedBytes[2])
            uulen += 3
            savedBytes.removeAll(keepingCapacity: true)
        }

        if uulen > 0 {
            let actualLength = uulen - uufill
            outIndex = flushLine(into: &output, at: outIndex, lengthOverride: actualLength)
        }

        output[outIndex] = encodeLength(0)
        output[outIndex + 1] = 0x0A
        outIndex += 2

        reset()
        return outIndex
    }

    /// Resets the encoder to its initial state.
    ///
    /// Resets the internal state of the encoder, clearing any buffered input bytes
    /// and the line buffer. After calling this method, the encoder can be reused
    /// to encode new content from the beginning.
    public func reset() {
        savedBytes.removeAll(keepingCapacity: true)
        lineBuffer.removeAll(keepingCapacity: true)
        uulen = 0
    }

    private func appendEncodedTriplet(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8) {
        lineBuffer.append(encodeValue((b0 >> 2) & 0x3F))
        lineBuffer.append(encodeValue(((b0 << 4) | ((b1 >> 4) & 0x0F)) & 0x3F))
        lineBuffer.append(encodeValue(((b1 << 2) | ((b2 >> 6) & 0x03)) & 0x3F))
        lineBuffer.append(encodeValue(b2 & 0x3F))
    }

    private func flushLine(into output: inout [UInt8], at index: Int, lengthOverride: Int) -> Int {
        var outIndex = index
        output[outIndex] = encodeLength(lengthOverride)
        outIndex += 1
        output.replaceSubrange(outIndex..<(outIndex + lineBuffer.count), with: lineBuffer)
        outIndex += lineBuffer.count
        output[outIndex] = 0x0A
        outIndex += 1
        lineBuffer.removeAll(keepingCapacity: true)
        uulen = 0
        return outIndex
    }

    private func encodeValue(_ value: UInt8) -> UInt8 {
        if value == 0 { return 0x60 }
        return value &+ 0x20
    }

    private func encodeLength(_ length: Int) -> UInt8 {
        let value = UInt8(length & 0xFF)
        return encodeValue(value)
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
