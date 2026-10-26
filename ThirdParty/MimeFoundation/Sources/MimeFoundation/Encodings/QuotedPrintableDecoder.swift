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
// QuotedPrintableDecoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally decodes content encoded with the Quoted-Printable encoding.
///
/// Quoted-Printable is an encoding often used in MIME to encode textual content outside
/// the ASCII range in order to ensure that the text remains intact when sent
/// via 7-bit transports such as SMTP.
///
/// The decoder processes encoded sequences (equals sign followed by two hexadecimal digits)
/// and converts them back to their original byte values. Soft line breaks (equals sign
/// followed by a line break) are removed, and invalid sequences are passed through unchanged.
public final class QuotedPrintableDecoder: MimeDecoder {
    /// Internal state machine states for the decoder.
    private enum State {
        case passThrough
        case equalSign
        case softBreak
        case decodeByte
    }

    private let rfc2047: Bool
    private var state: State = .passThrough
    private var saved: UInt8 = 0

    /// Initializes a new instance of the ``QuotedPrintableDecoder`` class.
    ///
    /// Creates a new Quoted-Printable decoder with the option to decode RFC 2047 encoded-word tokens.
    /// When `rfc2047` is `true`, underscore characters (`_`) are decoded as spaces, as specified
    /// by RFC 2047 for Q-encoding in MIME headers.
    ///
    /// - Parameter rfc2047: `true` if this decoder will be used to decode RFC 2047 encoded-word tokens;
    ///   otherwise, `false`.
    public init(rfc2047: Bool) {
        self.rfc2047 = rfc2047
    }

    /// Initializes a new instance of the ``QuotedPrintableDecoder`` class.
    ///
    /// Creates a new Quoted-Printable decoder for decoding standard Quoted-Printable content
    /// (not RFC 2047 encoded-word tokens).
    public convenience init() {
        self.init(rfc2047: false)
    }

    /// The content encoding that this decoder supports.
    ///
    /// Always returns ``ContentEncoding/quotedPrintable`` for this decoder.
    public var encoding: ContentEncoding {
        .quotedPrintable
    }

    /// Creates a copy of this decoder with its current state.
    ///
    /// Creates a new ``QuotedPrintableDecoder`` with exactly the same state as the current decoder,
    /// including any partial decode state. This allows the decoding process to be forked or
    /// saved at a particular point.
    ///
    /// - Returns: A new ``QuotedPrintableDecoder`` with identical state.
    public func copy() -> any MimeDecoder {
        let copied = QuotedPrintableDecoder(rfc2047: rfc2047)
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
        case .equalSign:
            // Add an extra byte in case the '=' character is not the start of a valid hex sequence
            return inputLength + 1
        case .softBreak, .decodeByte:
            // Add an extra 2 bytes in case the =X sequence is not the start of a valid hex sequence
            return inputLength + 2
        }
    }

    /// Decodes the specified input into the output buffer.
    ///
    /// Decodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the decoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// The decoder maintains state between calls to handle encoded sequences that span multiple
    /// input chunks. Invalid encoded sequences are passed through unchanged.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing Quoted-Printable encoded bytes to decode.
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
                    let c = input[index]
                    index += 1

                    if c == 0x3D {
                        state = .equalSign
                        break
                    } else if rfc2047 && c == 0x5F {
                        output[outIndex] = 0x20
                        outIndex += 1
                    } else {
                        output[outIndex] = c
                        outIndex += 1
                    }
                }
            case .equalSign:
                if index >= end { break }
                let c = input[index]
                index += 1

                if ByteClassification.isXDigit(c) {
                    state = .decodeByte
                    saved = c
                } else if c == 0x3D {
                    output[outIndex] = 0x3D
                    outIndex += 1
                } else if c == 0x0D {
                    state = .softBreak
                } else if c == 0x0A {
                    state = .passThrough
                } else {
                    state = .passThrough
                    output[outIndex] = 0x3D
                    output[outIndex + 1] = c
                    outIndex += 2
                }
            case .softBreak:
                state = .passThrough
                if index >= end { break }
                let c = input[index]
                index += 1
                if c != 0x0A {
                    output[outIndex] = 0x3D
                    output[outIndex + 1] = 0x0D
                    output[outIndex + 2] = c
                    outIndex += 3
                }
            case .decodeByte:
                if index >= end { break }
                let c = input[index]
                index += 1
                if ByteClassification.isXDigit(c) {
                    let high = ByteClassification.toXDigit(saved)
                    let low = ByteClassification.toXDigit(c)
                    output[outIndex] = (high << 4) | low
                    outIndex += 1
                } else {
                    output[outIndex] = 0x3D
                    output[outIndex + 1] = saved
                    output[outIndex + 2] = c
                    outIndex += 3
                }
                state = .passThrough
            }
        }

        return outIndex
    }

    /// Resets the decoder to its initial state.
    ///
    /// Resets the internal state of the decoder, clearing any partial decode state.
    /// After calling this method, the decoder can be reused to decode new content from the beginning.
    public func reset() {
        state = .passThrough
        saved = 0
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
