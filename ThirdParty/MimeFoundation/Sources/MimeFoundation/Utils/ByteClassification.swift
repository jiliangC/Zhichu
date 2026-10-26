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
// ByteClassification.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Internal utility for classifying byte values according to MIME and RFC 822 rules.
///
/// `ByteClassification` provides fast lookup methods to determine whether a byte
/// value has specific properties relevant to MIME parsing, such as whether it's
/// a valid atom character, whitespace, a control character, etc.
///
/// The implementation uses a lookup table initialized at startup for optimal
/// performance during parsing.
///
/// ## Common Classifications
///
/// - Atom characters: ``isAtom(_:)``, ``isAsciiAtom(_:)``
/// - Whitespace: ``isWhitespace(_:)``
/// - Control characters: ``isCtrl(_:)``
/// - MIME token characters: ``isToken(_:)``
/// - Domain-safe characters: ``isDomain(_:)``
/// - Hexadecimal digits: ``isXDigit(_:)``
enum ByteClassification {
    private struct CharType: OptionSet {
        let rawValue: UInt16

        static let ascii = CharType(rawValue: 1 << 0)
        static let atom = CharType(rawValue: 1 << 1)
        static let attrChar = CharType(rawValue: 1 << 2)
        static let blank = CharType(rawValue: 1 << 3)
        static let control = CharType(rawValue: 1 << 4)
        static let domainSafe = CharType(rawValue: 1 << 5)
        static let encodedPhraseSafe = CharType(rawValue: 1 << 6)
        static let encodedWordSafe = CharType(rawValue: 1 << 7)
        static let quotedPrintableSafe = CharType(rawValue: 1 << 8)
        static let space = CharType(rawValue: 1 << 9)
        static let special = CharType(rawValue: 1 << 10)
        static let tokenSpecial = CharType(rawValue: 1 << 11)
        static let whitespace = CharType(rawValue: 1 << 12)
        static let xdigit = CharType(rawValue: 1 << 13)
        static let phraseAtom = CharType(rawValue: 1 << 14)
        static let fieldText = CharType(rawValue: 1 << 15)

        static let asciiAtom: CharType = [.ascii, .atom]
    }

    private static let atomSafe = Array("!#$%&'*+-/=?^_`{|}~".utf8)
    private static let attributeSpecials = Array("*'%".utf8)
    private static let encodedWordSpecials = Array("()<>@,;:\"/[]?.=_".utf8)
    private static let encodedPhraseSafeSet = Array("!*+-/".utf8)
    private static let specials = Array("()<>[]:;@\\,.\"".utf8)
    private static let tokenSpecials = Array("()<>@,;:\\\"/[]?=".utf8)
    private static let whitespace = Array(" \t\r\n".utf8)

    private static let table: [CharType] = {
        var table = Array(repeating: CharType(), count: 256)

        for i in 0..<256 {
            if i < 127 {
                if i < 32 {
                    table[i].insert([.control, .tokenSpecial])
                }
                if i > 32 {
                    table[i].insert(.attrChar)
                }
                if i >= 32 && i != 61 {
                    table[i].insert([.quotedPrintableSafe, .encodedWordSafe])
                }
                if (i >= 0x30 && i <= 0x39) || (i >= 0x61 && i <= 0x7A) || (i >= 0x41 && i <= 0x5A) {
                    table[i].insert([.encodedPhraseSafe, .atom, .phraseAtom])
                }
                if (i >= 0x30 && i <= 0x39) || (i >= 0x61 && i <= 0x66) || (i >= 0x41 && i <= 0x46) {
                    table[i].insert(.xdigit)
                }
                if i >= 33 && i != 58 {
                    table[i].insert(.fieldText)
                }
                if (i >= 33 && i <= 90) || i >= 94 {
                    table[i].insert(.domainSafe)
                }
                table[i].insert(.ascii)
            } else {
                if i == 127 {
                    table[i].insert(.ascii)
                } else {
                    table[i].insert([.atom, .phraseAtom])
                }
                table[i].insert([.control, .tokenSpecial])
            }
        }

        table[0x09].insert([.quotedPrintableSafe, .blank])
        table[0x20].insert([.space, .blank])

        func setFlags(_ values: [UInt8], _ flag: CharType) {
            for value in values {
                table[Int(value)].insert(flag)
            }
        }

        func removeFlags(_ values: [UInt8], _ flag: CharType) {
            for value in values {
                table[Int(value)].remove(flag)
            }
        }

        setFlags(whitespace, .whitespace)
        setFlags(atomSafe, [.atom, .phraseAtom])
        setFlags(tokenSpecials, .tokenSpecial)
        setFlags(specials, .special)
        removeFlags(specials, [.atom, .phraseAtom])
        removeFlags(encodedWordSpecials, .encodedWordSafe)
        removeFlags(attributeSpecials + tokenSpecials, .attrChar)
        setFlags(encodedPhraseSafeSet, .encodedPhraseSafe)

        table[0x5B].insert(.phraseAtom)
        table[0x5D].insert(.phraseAtom)
        table[0x29].insert(.phraseAtom)

        return table
    }()

    /// Checks if a byte is a valid ASCII atom character.
    ///
    /// ASCII atom characters are a subset of atom characters that are also
    /// within the ASCII range (0-127).
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte is an ASCII atom character; `false` otherwise.
    static func isAsciiAtom(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.asciiAtom)
    }

    /// Checks if a byte is valid in an RFC 822 phrase atom.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte can appear in a phrase atom; `false` otherwise.
    static func isPhraseAtom(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.phraseAtom)
    }

    /// Checks if a byte is a valid RFC 822 atom character.
    ///
    /// Atom characters can appear in unquoted tokens in structured headers.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte is an atom character; `false` otherwise.
    static func isAtom(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.atom)
    }

    /// Checks if a byte is valid in MIME attribute values.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte can appear in an unquoted attribute value;
    ///   `false` otherwise.
    static func isAttr(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.attrChar)
    }

    /// Checks if a byte is a blank character (space or tab).
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte is 0x20 (space) or 0x09 (tab); `false` otherwise.
    static func isBlank(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.blank)
    }

    /// Checks if a byte is a control character.
    ///
    /// Control characters are bytes less than 0x20 or equal to 0x7F.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte is a control character; `false` otherwise.
    static func isCtrl(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.control)
    }

    /// Checks if a byte is safe to use in a domain name.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte can appear in a domain name; `false` otherwise.
    static func isDomain(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.domainSafe)
    }

    /// Checks if a byte is valid in unstructured header field text.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte can appear in field text; `false` otherwise.
    static func isFieldText(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.fieldText)
    }

    /// Checks if a byte can be represented literally in quoted-printable encoding.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte doesn't need to be encoded in quoted-printable;
    ///   `false` if it must be encoded as `=XX`.
    static func isQpSafe(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.quotedPrintableSafe)
    }

    /// Checks if a byte is a valid MIME token character.
    ///
    /// MIME tokens are used in headers like Content-Type and Content-Disposition.
    /// A valid token character is not a special, whitespace, or control character.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte can appear in a MIME token; `false` otherwise.
    static func isToken(_ byte: UInt8) -> Bool {
        let flags = table[Int(byte)]
        return !flags.contains(.tokenSpecial) && !flags.contains(.whitespace) && !flags.contains(.control)
    }

    /// Checks if a byte is whitespace (space, tab, CR, or LF).
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte is 0x20, 0x09, 0x0D, or 0x0A; `false` otherwise.
    static func isWhitespace(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.whitespace)
    }

    /// Checks if a byte is a hexadecimal digit (0-9, A-F, a-f).
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte represents a hex digit; `false` otherwise.
    static func isXDigit(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.xdigit)
    }

    /// Checks if a byte can be used unencoded in an RFC 2047 encoded-word.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte doesn't need encoding in an encoded-word;
    ///   `false` otherwise.
    static func isEncodedWordSafe(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.encodedWordSafe)
    }

    /// Checks if a byte can be used unencoded in an RFC 2047 encoded phrase.
    ///
    /// - Parameter byte: The byte value to check.
    /// - Returns: `true` if the byte doesn't need encoding in an encoded phrase;
    ///   `false` otherwise.
    static func isEncodedPhraseSafe(_ byte: UInt8) -> Bool {
        table[Int(byte)].contains(.encodedPhraseSafe)
    }

    /// Converts a hexadecimal digit byte to its numeric value.
    ///
    /// - Parameter byte: The hex digit byte (0-9, A-F, a-f).
    /// - Returns: The numeric value (0-15) of the hex digit.
    ///
    /// ## Example
    ///
    /// ```swift
    /// ByteClassification.toXDigit(0x41)  // 'A' -> 10
    /// ByteClassification.toXDigit(0x35)  // '5' -> 5
    /// ByteClassification.toXDigit(0x66)  // 'f' -> 15
    /// ```
    static func toXDigit(_ byte: UInt8) -> UInt8 {
        if byte >= 0x41 {
            if byte >= 0x61 {
                return byte &- 0x61 &+ 0x0A
            }
            return byte &- 0x41 &+ 0x0A
        }
        return byte &- 0x30
    }
}
