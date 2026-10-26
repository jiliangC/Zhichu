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
// BestEncodingFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum BestEncodingFilterError: Error, Equatable, Sendable {
    case invalidMaxLineLength
}

public final class BestEncodingFilter: MimeFilter {
    private var marker: [UInt8] = Array(repeating: 0, count: 5)
    private var maxline: Int = 0
    private var linelen: Int = 0
    private var count0: Int = 0
    private var count8: Int = 0
    private var markerLength: Int = 0
    private var hasMarker = false
    private var total: Int = 0
    private var pc: UInt8 = 0

    public init() {}

    public func getBestEncoding(_ constraint: EncodingConstraint, maxLineLength: Int = FormatOptions.defaultMaxLineLength) throws -> ContentEncoding {
        if maxLineLength < FormatOptions.minimumLineLength || maxLineLength > FormatOptions.maximumLineLength {
            throw BestEncodingFilterError.invalidMaxLineLength
        }

        switch constraint {
        case .sevenBit:
            if count0 > 0 {
                return .base64
            }
            if count8 > 0 {
                if count8 >= Int(Double(total) * 0.17) {
                    return .base64
                }
                return .quotedPrintable
            }
            if hasMarker || maxline > maxLineLength {
                return .quotedPrintable
            }
        case .eightBit:
            if count0 > 0 {
                return .base64
            }
            if hasMarker || maxline > maxLineLength {
                return .quotedPrintable
            }
            if count8 > 0 {
                return .eightBit
            }
        case .none:
            if hasMarker || maxline > maxLineLength {
                if count0 > 0 || count8 > Int(Double(total) * 0.17) {
                    return .base64
                }
                return .quotedPrintable
            }
            if count0 > 0 {
                return .binary
            }
            if count8 > 0 {
                return .eightBit
            }
        }

        return .sevenBit
    }

    public func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int) -> [UInt8] {
        if length > 0 {
            scan(input, startIndex: startIndex, length: length)
        }
        maxline = max(maxline, linelen)
        total += length
        outputIndex = startIndex
        outputLength = length
        return input
    }

    public func flush(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int) -> [UInt8] {
        filter(input, startIndex: startIndex, length: length, outputIndex: &outputIndex, outputLength: &outputLength)
    }

    public func reset() {
        hasMarker = false
        markerLength = 0
        linelen = 0
        maxline = 0
        count0 = 0
        count8 = 0
        total = 0
        pc = 0
    }

    private func scan(_ input: [UInt8], startIndex: Int, length: Int) {
        let end = startIndex + length
        var index = startIndex

        while index < end {
            let c = input[index]
            index += 1

            if c == UInt8(ascii: "\n") {
                if pc == UInt8(ascii: "\r") {
                    linelen = max(0, linelen - 1)
                }
                maxline = max(maxline, linelen)
                linelen = 0

                if !hasMarker && markerLength == 5 && isMboxMarker(marker) {
                    hasMarker = true
                }
                markerLength = 0
                pc = c
                continue
            }

            if c == 0 {
                count0 += 1
            } else if c > 127 {
                count8 += 1
            }

            if !hasMarker && markerLength < 5 {
                marker[markerLength] = c
                markerLength += 1
            }

            linelen += 1
            pc = c
        }
    }

    private func isMboxMarker(_ marker: [UInt8]) -> Bool {
        guard marker.count >= 5 else { return false }
        return marker[0] == UInt8(ascii: "F") &&
            marker[1] == UInt8(ascii: "r") &&
            marker[2] == UInt8(ascii: "o") &&
            marker[3] == UInt8(ascii: "m") &&
            marker[4] == UInt8(ascii: " ")
    }
}
