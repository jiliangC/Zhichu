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
// UUDecoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally decodes content encoded with the Unix-to-Unix (UUEncode) encoding.
///
/// The UUEncoding is an encoding that predates MIME and was used to encode binary content
/// such as images and other types of multimedia to ensure that the data remained intact
/// when sent via 7-bit transports such as SMTP.
///
/// These days, the UUEncoding has largely been deprecated in favor of the Base64 encoding,
/// however, some older mail clients still use it.
///
/// UUEncoded content is typically wrapped in `begin` and `end` markers. This decoder
/// can optionally skip scanning for the `begin` marker if only the payload is present.
public final class UUDecoder: MimeDecoder {
    /// Internal state machine states for the decoder.
    private enum State {
        case expectBegin
        case b
        case be
        case beg
        case begi
        case begin
        case expectPayload
        case payload
        case ended
    }

    private let payloadOnly: Bool
    private var state: State
    private var nsaved: UInt8 = 0
    private var uulen: Int = 0
    private var saved: UInt32 = 0

    /// Initializes a new instance of the ``UUDecoder`` class.
    ///
    /// Creates a new Unix-to-Unix decoder.
    ///
    /// - Parameter payloadOnly: If `true`, decoding begins immediately rather than after
    ///   finding a `begin` line. Set this to `true` when decoding content that does not
    ///   include the standard UUEncode begin/end markers.
    public init(payloadOnly: Bool = false) {
        self.payloadOnly = payloadOnly
        self.state = payloadOnly ? .payload : .expectBegin
    }

    /// The content encoding that this decoder supports.
    ///
    /// Always returns ``ContentEncoding/uuEncode`` for this decoder.
    public var encoding: ContentEncoding {
        .uuEncode
    }

    /// Creates a copy of this decoder with its current state.
    ///
    /// Creates a new ``UUDecoder`` with exactly the same state as the current decoder,
    /// including any partial decode state. This allows the decoding process to be forked
    /// or saved at a particular point.
    ///
    /// - Returns: A new ``UUDecoder`` with identical state.
    public func copy() -> any MimeDecoder {
        let copied = UUDecoder(payloadOnly: payloadOnly)
        copied.state = state
        copied.nsaved = nsaved
        copied.uulen = uulen
        copied.saved = saved
        return copied
    }

    /// Estimates the number of bytes needed to decode the specified number of input bytes.
    ///
    /// This method calculates the maximum possible output size. The estimate adds extra bytes
    /// to account for saved input bytes from a previous decode step.
    /// Use this to allocate an appropriately sized output buffer before calling
    /// ``decode(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be decoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        // Add an extra 3 bytes for the saved input bytes from previous decode step
        inputLength + 3
    }

    /// Decodes the specified input into the output buffer.
    ///
    /// Decodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the decoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// If `payloadOnly` is `false`, the decoder will scan for a `begin` line before
    /// starting to decode the payload. Decoding stops when a zero-length line is encountered.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing UUEncoded bytes to decode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to decode from the input buffer.
    ///   - output: The output buffer to write decoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    public func decode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        if state == .ended {
            return 0
        }

        var lastWasEoln = uulen == 0
        var index = startIndex
        let end = startIndex + length
        var outIndex = 0

        if state != .payload {
            index = scanBeginMarker(input, startIndex: index, end: end)
            if index >= end { return 0 }
        }

        while index < end {
            let byte = input[index]
            index += 1

            if byte == 0x0D {
                continue
            }

            if byte == 0x0A {
                lastWasEoln = true
                continue
            }

            if uulen == 0 || lastWasEoln {
                uulen = decodeValue(byte)
                lastWasEoln = false
                if uulen == 0 {
                    state = .ended
                    break
                }
                continue
            }

            if uulen > 0 {
                saved = (saved << 8) | UInt32(byte)
                nsaved &+= 1

                if nsaved == 4 {
                    let b0 = UInt8((saved >> 24) & 0xFF)
                    let b1 = UInt8((saved >> 16) & 0xFF)
                    let b2 = UInt8((saved >> 8) & 0xFF)
                    let b3 = UInt8(saved & 0xFF)

                    let d0 = decodeValue(b0)
                    let d1 = decodeValue(b1)
                    let d2 = decodeValue(b2)
                    let d3 = decodeValue(b3)

                    if uulen >= 3 {
                        output[outIndex] = UInt8((d0 << 2) | (d1 >> 4))
                        output[outIndex + 1] = UInt8(truncatingIfNeeded: (d1 << 4) | (d2 >> 2))
                        output[outIndex + 2] = UInt8(truncatingIfNeeded: (d2 << 6) | d3)
                        outIndex += 3
                        uulen -= 3
                    } else {
                        if uulen >= 1 {
                            output[outIndex] = UInt8((d0 << 2) | (d1 >> 4))
                            outIndex += 1
                            uulen -= 1
                        }
                        if uulen >= 1 {
                            output[outIndex] = UInt8(truncatingIfNeeded: (d1 << 4) | (d2 >> 2))
                            outIndex += 1
                            uulen -= 1
                        }
                    }

                    nsaved = 0
                    saved = 0
                }
            } else {
                break
            }
        }

        return outIndex
    }

    /// Resets the decoder to its initial state.
    ///
    /// Resets the internal state of the decoder, clearing any partial decode state.
    /// After calling this method, the decoder can be reused to decode new content from the beginning.
    public func reset() {
        state = payloadOnly ? .payload : .expectBegin
        nsaved = 0
        saved = 0
        uulen = 0
    }

    private func scanBeginMarker(_ input: [UInt8], startIndex: Int, end: Int) -> Int {
        var index = startIndex
        while index < end {
            if state == .expectBegin {
                if nsaved != 0 && nsaved != 0x0A {
                    while index < end && input[index] != 0x0A { index += 1 }
                    if index == end {
                        nsaved = input[end - 1]
                        return index
                    }
                    nsaved = input[index]
                    index += 1
                    if index == end { return index }
                }

                nsaved = input[index]
                index += 1
                if nsaved != 0x62 { continue }
                state = .b
                if index == end { return index }
            }

            if state == .b {
                nsaved = input[index]
                index += 1
                if nsaved != 0x65 { state = .expectBegin; continue }
                state = .be
                if index == end { return index }
            }

            if state == .be {
                nsaved = input[index]
                index += 1
                if nsaved != 0x67 { state = .expectBegin; continue }
                state = .beg
                if index == end { return index }
            }

            if state == .beg {
                nsaved = input[index]
                index += 1
                if nsaved != 0x69 { state = .expectBegin; continue }
                state = .begi
                if index == end { return index }
            }

            if state == .begi {
                nsaved = input[index]
                index += 1
                if nsaved != 0x6E { state = .expectBegin; continue }
                state = .begin
                if index == end { return index }
            }

            if state == .begin {
                nsaved = input[index]
                index += 1
                if nsaved != 0x20 { state = .expectBegin; continue }
                state = .expectPayload
                if index == end { return index }
            }

            if state == .expectPayload {
                while index < end && input[index] != 0x0A { index += 1 }
                if index == end { return index }
                state = .payload
                nsaved = 0
                return index + 1
            }
        }
        return index
    }

    private func decodeValue(_ byte: UInt8) -> Int {
        if byte == 0x60 { return 0 }
        return Int((byte &- 0x20) & 0x3F)
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
