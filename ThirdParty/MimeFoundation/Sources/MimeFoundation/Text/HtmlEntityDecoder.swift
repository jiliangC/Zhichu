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
// HtmlEntityDecoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An HTML entity decoder.
public class HtmlEntityDecoder {
    private var pushed: [Character] = []
    private var states: [Int] = []
    private var semicolon: Bool = false
    private var numeric: Bool = false
    private var digits: Int = 0
    private var xbase: Int = 0
    
    private static let maxEntityLength = 33

    /// Initialize a new instance of the `HtmlEntityDecoder` class.
    public init() {
        pushed.reserveCapacity(Self.maxEntityLength)
        states.reserveCapacity(Self.maxEntityLength)
    }

    /// Reset the entity decoder.
    public func reset() {
        pushed.removeAll(keepingCapacity: true)
        states.removeAll(keepingCapacity: true)
        semicolon = false
        numeric = false
        digits = 0
        xbase = 0
    }

    /// Push the specified character into the HTML entity decoder.
    ///
    /// - Parameter c: The character.
    /// - Returns: `true` if the character was accepted; otherwise, `false`.
    public func push(_ c: Character) -> Bool {
        if semicolon {
            return false
        }

        if pushed.isEmpty {
            if c != "&" {
                return false
            }
            pushed.append("&")
            states.append(0)
            return true
        }

        if pushed.count + 1 > Self.maxEntityLength {
            return false
        }

        if pushed.count == 1 && c == "#" {
            pushed.append("#")
            states.append(0)
            numeric = true
            return true
        }

        semicolon = (c == ";")

        if numeric {
            if c == ";" {
                states.append(states.last ?? 0)
                pushed.append(";")
                return true
            }
            return pushNumericEntity(c)
        }

        return pushNamedEntity(c)
    }

    private func pushNumericEntity(_ c: Character) -> Bool {
        var v: Int = 0

        if xbase == 0 {
            if c == "X" || c == "x" {
                states.append(0)
                pushed.append(c)
                xbase = 16
                return true
            }
            xbase = 10
        }

        if let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 {
            let val = scalar.value
            if val >= 0x30 && val <= 0x39 { // '0'-'9'
                v = Int(val - 0x30)
            } else if xbase == 16 {
                if val >= 0x61 && val <= 0x66 { // 'a'-'f'
                    v = Int(val - 0x61) + 10
                } else if val >= 0x41 && val <= 0x46 { // 'A'-'F'
                    v = Int(val - 0x41) + 10
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            return false
        }

        if v >= xbase {
            return false
        }

        let lastState = states.last ?? 0
        
        // check for overflow
        if lastState > Int.max / xbase {
            return false
        }
        
        let newState = (lastState * xbase) + v
        states.append(newState)
        pushed.append(c)
        digits += 1
        return true
    }

    private func pushNamedEntity(_ c: Character) -> Bool {
        pushed.append(c)
        states.append(0)
        return true
    }

    /// Get the decoded entity value.
    ///
    /// - Returns: The value.
    public func getValue() -> String {
        if numeric {
            return getNumericEntityValue()
        }
        return getNamedEntityValue()
    }

    private func getNumericEntityValue() -> String {
        if digits == 0 || !semicolon {
            return String(pushed)
        }

        let state = states.last ?? 0
        
        switch state {
        case 0x00: return "\u{FFFD}"
        case 0x80: return "\u{20AC}"
        case 0x82: return "\u{201A}"
        case 0x83: return "\u{0192}"
        case 0x84: return "\u{201E}"
        case 0x85: return "\u{2026}"
        case 0x86: return "\u{2020}"
        case 0x87: return "\u{2021}"
        case 0x88: return "\u{02C6}"
        case 0x89: return "\u{2030}"
        case 0x8A: return "\u{0160}"
        case 0x8B: return "\u{2039}"
        case 0x8C: return "\u{0152}"
        case 0x8E: return "\u{017D}"
        case 0x91: return "\u{2018}"
        case 0x92: return "\u{2019}"
        case 0x93: return "\u{201C}"
        case 0x94: return "\u{201D}"
        case 0x95: return "\u{2022}"
        case 0x96: return "\u{2013}"
        case 0x97: return "\u{2014}"
        case 0x98: return "\u{02DC}"
        case 0x99: return "\u{2122}"
        case 0x9A: return "\u{0161}"
        case 0x9B: return "\u{203A}"
        case 0x9C: return "\u{0153}"
        case 0x9E: return "\u{017E}"
        case 0x9F: return "\u{0178}"
        default:
            if (state >= 0xD800 && state <= 0xDFFF) || state > 0x10FFFF {
                return "\u{FFFD}"
            }
            if let scalar = UnicodeScalar(state) {
                return String(Character(scalar))
            }
            return String(pushed)
        }
    }

    private static let namedEntities: [String: String] = [
        "Aacute": "\u{00C1}", "aacute": "\u{00E1}", "Acirc": "\u{00C2}", "acirc": "\u{00E2}",
        "acute": "\u{00B4}", "AElig": "\u{00C6}", "aelig": "\u{00E6}", "Agrave": "\u{00C0}",
        "agrave": "\u{00E0}", "amp": "&", "AMP": "&", "Aring": "\u{00C5}", "aring": "\u{00E5}",
        "Atilde": "\u{00C3}", "atilde": "\u{00E3}", "Auml": "\u{00C4}", "auml": "\u{00E4}",
        "brvbar": "\u{00A6}", "Ccedil": "\u{00C7}", "ccedil": "\u{00E7}", "cedil": "\u{00B8}",
        "cent": "\u{00A2}", "copy": "\u{00A9}", "COPY": "\u{00A9}", "curren": "\u{00A4}",
        "deg": "\u{00B0}", "divide": "\u{00F7}", "Eacute": "\u{00C9}", "eacute": "\u{00E9}",
        "Ecirc": "\u{00CA}", "ecirc": "\u{00EA}", "Egrave": "\u{00C8}", "egrave": "\u{00E8}",
        "ETH": "\u{00D0}", "eth": "\u{00F0}", "Euml": "\u{00CB}", "euml": "\u{00EB}",
        "frac12": "\u{00BD}", "frac14": "\u{00BC}", "frac34": "\u{00BE}", "gt": ">", "GT": ">",
        "Iacute": "\u{00CD}", "iacute": "\u{00ED}", "Icirc": "\u{00CE}", "icirc": "\u{00EE}",
        "iexcl": "\u{00A1}", "Igrave": "\u{00CC}", "igrave": "\u{00EC}", "iquest": "\u{00BF}",
        "Iuml": "\u{00CF}", "iuml": "\u{00EF}", "laquo": "\u{00AB}", "lt": "<", "LT": "<",
        "macr": "\u{00AF}", "micro": "\u{00B5}", "middot": "\u{00B7}", "nbsp": "\u{00A0}",
        "not": "\u{00AC}", "Ntilde": "\u{00D1}", "ntilde": "\u{00F1}", "Oacute": "\u{00D3}",
        "oacute": "\u{00F3}", "Ocirc": "\u{00D4}", "ocirc": "\u{00F4}", "Ograve": "\u{00D2}",
        "ograve": "\u{00F2}", "ordf": "\u{00AA}", "ordm": "\u{00BA}", "Oslash": "\u{00D8}",
        "oslash": "\u{00F8}", "Otilde": "\u{00D5}", "otilde": "\u{00F5}", "Ouml": "\u{00D6}",
        "ouml": "\u{00F6}", "para": "\u{00B6}", "plusmn": "\u{00B1}", "pound": "\u{00A3}",
        "quot": "\"", "QUOT": "\"", "reg": "\u{00AE}", "REG": "\u{00AE}", "sect": "\u{00A7}",
        "shy": "\u{00AD}", "sup1": "\u{00B9}", "sup2": "\u{00B2}", "sup3": "\u{00B3}",
        "szlig": "\u{00DF}", "THORN": "\u{00DE}", "thorn": "\u{00FE}", "times": "\u{00D7}",
        "Uacute": "\u{00DA}", "uacute": "\u{00FA}", "Ucirc": "\u{00DB}", "ucirc": "\u{00FB}",
        "Ugrave": "\u{00D9}", "ugrave": "\u{00F9}", "uml": "\u{00A8}", "Uuml": "\u{00DC}",
        "uuml": "\u{00FC}", "Yacute": "\u{00DD}", "yacute": "\u{00FD}", "yen": "\u{00A5}",
        "yuml": "\u{00FF}"
    ]

    private func getNamedEntityValue() -> String {
        let input = String(pushed)
        if !semicolon {
            return input
        }
        
        let name = String(pushed.dropFirst().dropLast())
        if let value = Self.namedEntities[name] {
            return value
        }
        
        return input
    }
}
