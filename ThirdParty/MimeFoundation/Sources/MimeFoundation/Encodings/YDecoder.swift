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
// YDecoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Incrementally decodes content encoded with the yEnc encoding.
///
/// The yEncoding is an encoding that is most commonly used with Usenet and
/// is a binary encoding that includes a 32-bit cyclic redundancy check.
///
/// For more information, see [www.yenc.org](http://www.yenc.org).
public final class YDecoder: MimeDecoder {
    private enum State {
        case expectYBegin
        case yBeginEqual
        case yBeginEqualY
        case yBeginEqualYB
        case yBeginEqualYBe
        case yBeginEqualYBeg
        case yBeginEqualYBegi
        case yBeginEqualYBegin
        case expectYBeginNewLine
        case expectYPartOrPayload
        case yPartEqual
        case yPartEqualY
        case yPartEqualYP
        case yPartEqualYPa
        case yPartEqualYPar
        case yPartEqualYPart
        case expectYPartNewLine
        case payload
        case ended
    }

    private let initial: State
    private var state: State
    private var escaped: Bool = false
    private var octet: UInt8 = 0
    private var eoln: Bool = true
    private var crc: Crc32

    /// Initialize a new instance of the ``YDecoder`` class.
    ///
    /// Creates a new yEnc decoder.
    ///
    /// - Parameter payloadOnly: If `true`, decoding begins immediately rather than after finding an =ybegin line.
    public init(payloadOnly: Bool = false) {
        self.initial = payloadOnly ? .payload : .expectYBegin
        self.state = self.initial
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
    /// Gets the encoding that the decoder supports.
    public var encoding: ContentEncoding {
        .default
    }

    /// Clone the ``YDecoder`` with its current state.
    ///
    /// Creates a new ``YDecoder`` with exactly the same state as the current decoder.
    ///
    /// - Returns: A new ``YDecoder`` with identical state.
    public func copy() -> any MimeDecoder {
        let copied = YDecoder(payloadOnly: initial == .payload)
        copied.crc = crc.copy()
        copied.escaped = escaped
        copied.state = state
        copied.octet = octet
        copied.eoln = eoln
        return copied
    }

    /// Estimate the length of the output.
    ///
    /// Estimates the number of bytes needed to decode the specified number of input bytes.
    ///
    /// - Parameter inputLength: The input length.
    /// - Returns: The estimated output length.
    public func estimateOutputLength(_ inputLength: Int) -> Int {
        inputLength
    }

    /// Decode the specified input into the output buffer.
    ///
    /// Decodes the specified input into the output buffer.
    ///
    /// The output buffer should be large enough to hold all the decoded input. For estimating the size needed for the output buffer, see ``estimateOutputLength(_:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer.
    ///   - output: The output buffer.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if `startIndex` and `length` do not specify a valid range in the `input` array.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if `startIndex` and `length` do not specify a valid range in the `input` array.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if `output` is not large enough to contain the decoded content. Use the ``estimateOutputLength(_:)`` method to properly determine the necessary length of the `output` array.
    public func decode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int {
        try validateArguments(input, startIndex: startIndex, length: length, output: output)

        let end = startIndex + length
        var index = startIndex
        var outIndex = 0

        if state != .payload {
            index = scanYBeginMarker(input, startIndex: index, end: end)
            if index >= end {
                return 0
            }
        }

        if state == .ended {
            return 0
        }

        while index < end {
            let byte = input[index]
            index += 1
            octet = byte

            if octet == 0x0D {
                escaped = false
                continue
            }

            if octet == 0x0A {
                escaped = false
                eoln = true
                continue
            }

            if escaped {
                if eoln && octet == 0x79 {
                    state = .ended
                    break
                }
                escaped = false
                eoln = false
                octet &-= 64
            } else if octet == 0x3D {
                escaped = true
                continue
            } else {
                eoln = false
            }

            octet &-= 42
            _ = crc.update(octet)
            output[outIndex] = octet
            outIndex += 1
        }

        return outIndex
    }

    /// Reset the decoder.
    ///
    /// Resets the state of the decoder.
    public func reset() {
        octet = 0x0A
        state = initial
        escaped = false
        eoln = true
        crc.reset()
    }

    private func scanYBeginMarker(_ input: [UInt8], startIndex: Int, end: Int) -> Int {
        var index = startIndex

        while index < end {
            if state == .ended {
                return end
            }
            if state == .expectYBegin {
                if octet != 0x0A {
                    while index < end && input[index] != 0x0A { index += 1 }
                    if index == end {
                        octet = input[end - 1]
                        break
                    }
                    octet = input[index]
                    index += 1
                    if index == end { break }
                }

                octet = input[index]
                index += 1
                if octet != 0x3D { continue }
                state = .yBeginEqual
                if index == end { break }
            }

            if state == .yBeginEqual {
                octet = input[index]
                index += 1
                if octet != 0x79 { state = .expectYBegin; continue }
                state = .yBeginEqualY
                if index == end { break }
            }

            if state == .yBeginEqualY {
                octet = input[index]
                index += 1
                if octet != 0x62 { state = .expectYBegin; continue }
                state = .yBeginEqualYB
                if index == end { break }
            }

            if state == .yBeginEqualYB {
                octet = input[index]
                index += 1
                if octet != 0x65 { state = .expectYBegin; continue }
                state = .yBeginEqualYBe
                if index == end { break }
            }

            if state == .yBeginEqualYBe {
                octet = input[index]
                index += 1
                if octet != 0x67 { state = .expectYBegin; continue }
                state = .yBeginEqualYBeg
                if index == end { break }
            }

            if state == .yBeginEqualYBeg {
                octet = input[index]
                index += 1
                if octet != 0x69 { state = .expectYBegin; continue }
                state = .yBeginEqualYBegi
                if index == end { break }
            }

            if state == .yBeginEqualYBegi {
                octet = input[index]
                index += 1
                if octet != 0x6E { state = .expectYBegin; continue }
                state = .yBeginEqualYBegin
                if index == end { break }
            }

            if state == .yBeginEqualYBegin {
                octet = input[index]
                index += 1
                if octet != 0x20 { state = .expectYBegin; continue }
                state = .expectYBeginNewLine
                if index == end { break }
            }

            if state == .expectYBeginNewLine {
                while index < end && input[index] != 0x0A { index += 1 }
                if index == end {
                    octet = input[end - 1]
                    break
                }
                state = .expectYPartOrPayload
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .expectYPartOrPayload {
                if index >= end { break }
                if input[index] != 0x3D {
                    state = .payload
                    escaped = false
                    eoln = true
                    break
                }

                state = .yPartEqual
                octet = input[index]
                index += 1
                escaped = true
                if index == end { break }
            }

            if state == .yPartEqual {
                if index >= end { break }
                if input[index] != 0x79 {
                    state = .payload
                    escaped = false
                    eoln = true
                    return index
                }

                state = .yPartEqualY
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .yPartEqualY {
                if index >= end { break }
                if input[index] == 0x65 {
                    state = .ended
                    return index
                }

                if input[index] != 0x70 {
                    state = .expectYBeginNewLine
                    continue
                }

                state = .yPartEqualYP
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .yPartEqualYP {
                if index >= end { break }
                if input[index] != 0x61 {
                    state = .expectYBeginNewLine
                    continue
                }

                state = .yPartEqualYPa
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .yPartEqualYPa {
                if index >= end { break }
                if input[index] != 0x72 {
                    state = .expectYBeginNewLine
                    continue
                }

                state = .yPartEqualYPar
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .yPartEqualYPar {
                if index >= end { break }
                if input[index] != 0x74 {
                    state = .expectYBeginNewLine
                    continue
                }

                state = .yPartEqualYPart
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .yPartEqualYPart {
                if index >= end { break }
                if input[index] != 0x20 {
                    state = .expectYBeginNewLine
                    continue
                }

                state = .expectYPartNewLine
                octet = input[index]
                index += 1
                if index == end { break }
            }

            if state == .expectYPartNewLine {
                while index < end && input[index] != 0x0A { index += 1 }
                if index == end {
                    octet = input[end - 1]
                    break
                }
                state = .payload
                octet = input[index]
                index += 1
                escaped = false
                eoln = true
                break
            }
        }

        return index
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int, output: [UInt8]) throws {
        if startIndex < 0 || startIndex > input.count { throw MimeCodingError.startIndexOutOfRange }
        if length < 0 || length > (input.count - startIndex) { throw MimeCodingError.lengthOutOfRange }
        if output.count < estimateOutputLength(length) { throw MimeCodingError.outputTooSmall }
    }
}
