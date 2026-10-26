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
// Punycode.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A protocol for encoding and decoding international domain names.
///
/// An interface for encoding and decoding international domain names.
public protocol PunycodeCoding: Sendable {
    /// Encode a Unicode domain name, converting it to an ASCII-safe representation.
    ///
    /// Encodes a Unicode domain name, converting it to an ASCII-safe representation
    /// according to the rules defined by the IDNA standard.
    ///
    /// - Parameter unicode: The Unicode domain name.
    /// - Returns: The ASCII-encoded domain name.
    func encode(_ unicode: String) -> String

    /// Encode a Unicode domain name, converting it to an ASCII-safe representation.
    ///
    /// Encodes a Unicode domain name, converting it to an ASCII-safe representation
    /// according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - unicode: The Unicode domain name.
    ///   - index: A zero-based offset into `unicode` that specifies the start of the substring to convert. The conversion operation continues to the end of the string.
    /// - Returns: The ASCII-encoded domain name.
    func encode(_ unicode: String, index: Int) -> String

    /// Encode a Unicode domain name, converting it to an ASCII-safe representation.
    ///
    /// Encodes a Unicode domain name, converting it to an ASCII-safe representation
    /// according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - unicode: The Unicode domain name.
    ///   - index: A zero-based offset into `unicode` that specifies the start of the substring to convert.
    ///   - count: The number of characters to convert in the substring that starts at the position specified by `index` in the `unicode` string.
    /// - Returns: The ASCII-encoded domain name.
    func encode(_ unicode: String, index: Int, count: Int) -> String

    /// Decode a domain name, converting it to a string of Unicode characters.
    ///
    /// Decodes a domain name, converting it to Unicode, according to the rules defined by the IDNA standard.
    ///
    /// - Parameter ascii: The ASCII-encoded domain name.
    /// - Returns: The Unicode domain name.
    func decode(_ ascii: String) -> String

    /// Decode a domain name, converting it to a string of Unicode characters.
    ///
    /// Decodes a domain name, converting it to Unicode, according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - ascii: The ASCII-encoded domain name.
    ///   - index: A zero-based offset into `ascii` that specifies the start of the substring to convert. The conversion operation continues to the end of the string.
    /// - Returns: The Unicode domain name.
    func decode(_ ascii: String, index: Int) -> String

    /// Decode a domain name, converting it to a string of Unicode characters.
    ///
    /// Decodes a domain name, converting it to Unicode, according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - ascii: The ASCII-encoded domain name.
    ///   - index: A zero-based offset into `ascii` that specifies the start of the substring to convert.
    ///   - count: The number of characters to convert in the substring that starts at the position specified by `index` in the `ascii` string.
    /// - Returns: The Unicode domain name.
    func decode(_ ascii: String, index: Int, count: Int) -> String
}

/// A class for encoding and decoding international domain names.
///
/// A class for encoding and decoding international domain names.
public final class Punycode: PunycodeCoding, Sendable {
    private enum PunycodeError: Error {
        case invalidInput
    }

    private static let base = 36
    private static let tmin = 1
    private static let tmax = 26
    private static let skew = 38
    private static let damp = 700
    private static let initialBias = 72
    private static let initialN = 128

    private static let prefix = "xn--"
    private static let separators: Set<UnicodeScalar> = Set(
        [".", "\u{3002}", "\u{FF0E}", "\u{FF61}"].compactMap { $0.unicodeScalars.first }
    )

    /// Initialize a new instance of the ``Punycode`` class.
    ///
    /// Creates a new instance of ``Punycode``.
    public init() {}

    /// Encode a Unicode domain name, converting it to an ASCII-safe representation.
    ///
    /// Encodes a Unicode domain name, converting it to an ASCII-safe representation
    /// according to the rules defined by the IDNA standard.
    ///
    /// - Parameter unicode: The Unicode domain name.
    /// - Returns: The ASCII-encoded domain name.
    public func encode(_ unicode: String) -> String {
        do {
            return try encodeDomain(unicode)
        } catch {
            return unicode
        }
    }

    /// Encode a Unicode domain name, converting it to an ASCII-safe representation.
    ///
    /// Encodes a Unicode domain name, converting it to an ASCII-safe representation
    /// according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - unicode: The Unicode domain name.
    ///   - index: A zero-based offset into `unicode` that specifies the start of the substring to convert. The conversion operation continues to the end of the string.
    /// - Returns: The ASCII-encoded domain name.
    public func encode(_ unicode: String, index: Int) -> String {
        guard let substring = substring(unicode, index: index, count: nil) else {
            return ""
        }
        let value = String(substring)
        do {
            return try encodeDomain(value)
        } catch {
            return value
        }
    }

    /// Encode a Unicode domain name, converting it to an ASCII-safe representation.
    ///
    /// Encodes a Unicode domain name, converting it to an ASCII-safe representation
    /// according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - unicode: The Unicode domain name.
    ///   - index: A zero-based offset into `unicode` that specifies the start of the substring to convert.
    ///   - count: The number of characters to convert in the substring that starts at the position specified by `index` in the `unicode` string.
    /// - Returns: The ASCII-encoded domain name.
    public func encode(_ unicode: String, index: Int, count: Int) -> String {
        guard let substring = substring(unicode, index: index, count: count) else {
            return ""
        }
        let value = String(substring)
        do {
            return try encodeDomain(value)
        } catch {
            return value
        }
    }

    /// Decode a domain name, converting it to a string of Unicode characters.
    ///
    /// Decodes a domain name, converting it to Unicode, according to the rules defined by the IDNA standard.
    ///
    /// - Parameter ascii: The ASCII-encoded domain name.
    /// - Returns: The Unicode domain name.
    public func decode(_ ascii: String) -> String {
        do {
            return try decodeDomain(ascii)
        } catch {
            return ascii
        }
    }

    /// Decode a domain name, converting it to a string of Unicode characters.
    ///
    /// Decodes a domain name, converting it to Unicode, according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - ascii: The ASCII-encoded domain name.
    ///   - index: A zero-based offset into `ascii` that specifies the start of the substring to convert. The conversion operation continues to the end of the string.
    /// - Returns: The Unicode domain name.
    public func decode(_ ascii: String, index: Int) -> String {
        guard let substring = substring(ascii, index: index, count: nil) else {
            return ""
        }
        let value = String(substring)
        do {
            return try decodeDomain(value)
        } catch {
            return value
        }
    }

    /// Decode a domain name, converting it to a string of Unicode characters.
    ///
    /// Decodes a domain name, converting it to Unicode, according to the rules defined by the IDNA standard.
    ///
    /// - Parameters:
    ///   - ascii: The ASCII-encoded domain name.
    ///   - index: A zero-based offset into `ascii` that specifies the start of the substring to convert.
    ///   - count: The number of characters to convert in the substring that starts at the position specified by `index` in the `ascii` string.
    /// - Returns: The Unicode domain name.
    public func decode(_ ascii: String, index: Int, count: Int) -> String {
        guard let substring = substring(ascii, index: index, count: count) else {
            return ""
        }
        let value = String(substring)
        do {
            return try decodeDomain(value)
        } catch {
            return value
        }
    }

    private func substring(_ string: String, index: Int, count: Int?) -> Substring? {
        let length = string.utf16.count
        guard index >= 0, index <= length else {
            return nil
        }
        let start = String.Index(utf16Offset: index, in: string)
        if let count {
            guard count >= 0, index + count <= length else {
                return nil
            }
            let end = String.Index(utf16Offset: index + count, in: string)
            return string[start..<end]
        }
        return string[start...]
    }

    private func encodeDomain(_ unicode: String) throws -> String {
        try transformDomain(unicode) { label in
            try encodeLabel(label)
        }
    }

    private func decodeDomain(_ ascii: String) throws -> String {
        try transformDomain(ascii) { label in
            try decodeLabel(label)
        }
    }

    private func transformDomain(_ input: String, transform: (String) throws -> String) rethrows -> String {
        var output = ""
        var current = ""
        current.reserveCapacity(input.count)
        output.reserveCapacity(input.count)

        for scalar in input.unicodeScalars {
            if Self.separators.contains(scalar) {
                output += try transform(current)
                output.append(".")
                current.removeAll(keepingCapacity: true)
            } else {
                current.unicodeScalars.append(scalar)
            }
        }

        output += try transform(current)
        return output
    }

    private func encodeLabel(_ label: String) throws -> String {
        guard !label.isEmpty else {
            return label
        }

        var hasNonAscii = false
        for scalar in label.unicodeScalars where scalar.value >= 0x80 {
            hasNonAscii = true
            break
        }
        if !hasNonAscii {
            return label
        }

        let codePoints = label.unicodeScalars.map { Int($0.value) }
        var outputScalars: [UnicodeScalar] = []
        outputScalars.reserveCapacity(label.count + 8)

        for cp in codePoints where cp < 0x80 {
            if let scalar = UnicodeScalar(cp) {
                outputScalars.append(scalar)
            } else {
                throw PunycodeError.invalidInput
            }
        }

        let basicCount = outputScalars.count
        var output = String(String.UnicodeScalarView(outputScalars))
        if basicCount > 0 {
            output.append("-")
        }

        var n = Self.initialN
        var delta = 0
        var bias = Self.initialBias
        var handled = basicCount

        while handled < codePoints.count {
            var m = Int.max
            for cp in codePoints where cp >= n {
                if cp < m {
                    m = cp
                }
            }
            if m == Int.max {
                throw PunycodeError.invalidInput
            }

            let diff = m - n
            let increment = (handled + 1)
            if diff > (Int.max - delta) / increment {
                throw PunycodeError.invalidInput
            }
            delta += diff * increment
            n = m

            for cp in codePoints {
                if cp < n {
                    delta += 1
                } else if cp == n {
                    var q = delta
                    var k = Self.base
                    while true {
                        let t = threshold(k: k, bias: bias)
                        if q < t {
                            break
                        }
                        let digit = t + ((q - t) % (Self.base - t))
                        output.append(encodeDigit(digit))
                        q = (q - t) / (Self.base - t)
                        k += Self.base
                    }
                    output.append(encodeDigit(q))
                    bias = adapt(delta: delta, numPoints: handled + 1, firstTime: handled == basicCount)
                    delta = 0
                    handled += 1
                }
            }

            delta += 1
            n += 1
        }

        return Self.prefix + output
    }

    private func decodeLabel(_ label: String) throws -> String {
        guard !label.isEmpty else {
            return label
        }
        if !label.lowercased().hasPrefix(Self.prefix) {
            return label
        }

        let input = String(label.dropFirst(Self.prefix.count))
        var output: [UInt32] = []
        output.reserveCapacity(input.count)

        let bytes = Array(input.utf8)
        var index = 0
        if let delimIndex = bytes.lastIndex(of: 0x2D) {
            for byte in bytes[..<delimIndex] {
                output.append(UInt32(byte))
            }
            index = delimIndex + 1
        }

        var n = Self.initialN
        var i = 0
        var bias = Self.initialBias

        while index < bytes.count {
            let oldi = i
            var w = 1
            var k = Self.base

            while true {
                if index >= bytes.count {
                    throw PunycodeError.invalidInput
                }
                let digit = decodeDigit(bytes[index])
                index += 1
                if digit < 0 {
                    throw PunycodeError.invalidInput
                }
                if digit > (Int.max - i) / w {
                    throw PunycodeError.invalidInput
                }
                i += digit * w

                let t = threshold(k: k, bias: bias)
                if digit < t {
                    break
                }
                let baseMinusT = Self.base - t
                if w > Int.max / baseMinusT {
                    throw PunycodeError.invalidInput
                }
                w *= baseMinusT
                k += Self.base
            }

            let outCount = output.count + 1
            bias = adapt(delta: i - oldi, numPoints: outCount, firstTime: oldi == 0)

            let nIncrement = i / outCount
            if n > Int.max - nIncrement {
                throw PunycodeError.invalidInput
            }
            n += nIncrement
            i = i % outCount

            output.insert(UInt32(n), at: i)
            i += 1
        }

        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(output.count)
        for value in output {
            guard let scalar = UnicodeScalar(value) else {
                throw PunycodeError.invalidInput
            }
            scalars.append(scalar)
        }

        return String(scalars)
    }

    private func threshold(k: Int, bias: Int) -> Int {
        if k <= bias {
            return Self.tmin
        }
        if k >= bias + Self.tmax {
            return Self.tmax
        }
        return k - bias
    }

    private func adapt(delta: Int, numPoints: Int, firstTime: Bool) -> Int {
        var delta = firstTime ? (delta / Self.damp) : (delta / 2)
        delta += delta / numPoints
        var k = 0
        while delta > ((Self.base - Self.tmin) * Self.tmax) / 2 {
            delta /= (Self.base - Self.tmin)
            k += Self.base
        }
        return k + (Self.base - Self.tmin + 1) * delta / (delta + Self.skew)
    }

    private func encodeDigit(_ digit: Int) -> Character {
        if digit < 26 {
            return Character(UnicodeScalar(digit + 97)!)
        }
        return Character(UnicodeScalar(digit - 26 + 48)!)
    }

    private func decodeDigit(_ byte: UInt8) -> Int {
        if byte >= 0x30 && byte <= 0x39 {
            return Int(byte - 0x30) + 26
        }
        if byte >= 0x41 && byte <= 0x5A {
            return Int(byte - 0x41)
        }
        if byte >= 0x61 && byte <= 0x7A {
            return Int(byte - 0x61)
        }
        return -1
    }
}
