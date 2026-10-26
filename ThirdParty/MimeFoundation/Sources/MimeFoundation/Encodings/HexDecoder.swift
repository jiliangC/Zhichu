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
// HexDecoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally decodes content encoded with URI percent-encoding (hex encoding).
///
/// This decoder is primarily used for decoding parameter values encoded according to
/// the rules specified by RFC 2184 and RFC 2231, which define mechanisms for
/// encoding non-ASCII characters in MIME header parameters.
///
/// The decoder converts percent-encoded sequences (e.g., `%20` for a space) back to
/// their original byte values. Invalid sequences (percent sign not followed by two
/// valid hexadecimal digits) are passed through unchanged.
public final class HexDecoder: MimeDecoder {
    /// Internal state machine states for the decoder.
    private enum State {
        case passThrough
        case percent
        case decodeByte
    }

    private var state: State = .passThrough
    private var saved: UInt8 = 0

    /// Initializes a new instance of the ``HexDecoder`` class.
    ///
    /// Creates a new hex decoder.
    public init() {}

    /// The content encoding that this decoder supports.
    ///
    /// Returns ``ContentEncoding/default`` as this is not a standard MIME content transfer encoding.
    public var encoding: ContentEncoding {
        .default
    }

    /// Creates a copy of this decoder with its current state.
    ///
    /// Creates a new ``HexDecoder`` with exactly the same state as the current decoder,
    /// including any partial decode state. This allows the decoding process to be forked
    /// or saved at a particular point.
    ///
    /// - Returns: A new ``HexDecoder`` with identical state.
    public func copy() -> any MimeDecoder {
        let copied = HexDecoder()
        copied.state = state
        copied.saved = saved
        return copied
    }

    /// Estimates the number of bytes needed to decode the specified number of input bytes.
    ///
    /// This method calculates the maximum possible output size based on the current decoder state.
    /// In the worst case, an incomplete encoded sequence from a previous call might need to be
    /// passed through unchanged, requiring additional output space.
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``decode(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be decoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        switch state {
        case .passThrough:
            return inputLength
        case .percent:
            // Add an extra byte in case the '%' character is not the start of a valid hex sequence
            return inputLength + 1
        case .decodeByte:
            // Add an extra 2 bytes in case the %X sequence is not the start of a valid hex sequence
            return inputLength + 2
        }
    }

    /// Decodes the specified input into the output buffer.
    ///
    /// Decodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the decoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// The decoder converts percent-encoded sequences (`%XX`) back to their original byte values.
    /// Invalid sequences are passed through unchanged.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing percent-encoded bytes to decode.
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
            switch state {
            case .passThrough:
                while index < end {
                    let byte = input[index]
                    index += 1
                    if byte == 0x25 {
                        state = .percent
                        break
                    }
                    output[outIndex] = byte
                    outIndex += 1
                }
            case .percent:
                if index < end {
                    saved = input[index]
                    index += 1
                    state = .decodeByte
                }
            case .decodeByte:
                if index < end {
                    let byte = input[index]
                    index += 1
                    if ByteClassification.isXDigit(byte) && ByteClassification.isXDigit(saved) {
                        let high = ByteClassification.toXDigit(saved)
                        let low = ByteClassification.toXDigit(byte)
                        output[outIndex] = (high << 4) | low
                        outIndex += 1
                    } else {
                        output[outIndex] = 0x25
                        output[outIndex + 1] = saved
                        output[outIndex + 2] = byte
                        outIndex += 3
                    }
                    state = .passThrough
                }
            }
        }

        return outIndex
    }

    public func reset() {
        state = .passThrough
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
