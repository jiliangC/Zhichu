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
// UrlScanner.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A URL match result.
///
/// Contains information about a matched URL pattern in text.
struct UrlMatch {
    let pattern: String
    let prefix: String
    var startIndex: Int = 0
    var endIndex: Int = 0
}

/// URL pattern types.
///
/// Identifies the type of URL pattern for proper parsing.
enum UrlPatternType {
    case addrspec
    case mailto
    case file
    case web
}

/// A URL pattern.
///
/// Defines a pattern for matching URLs in text.
struct UrlPattern: Hashable {
    let type: UrlPatternType
    let pattern: String
    let prefix: String
}

/// A URL scanner for detecting URLs in text.
///
/// Scans text for various URL patterns including email addresses, web URLs,
/// and file URLs using an Aho-Corasick trie for efficient pattern matching.
final class UrlScanner {
    private static let atomCharacters = "!#$%&'*+-/=?^_`{|}~"
    private static let urlSafeCharacters = "$-_.+!*'(),{}|\\^~[]`#%\";/?:@&="
    private static let atomCharacterSet = Set(atomCharacters)
    private static let urlSafeCharacterSet = Set(urlSafeCharacters)

    private let trie = Trie(ignoreCase: true)
    private var patterns: [String: UrlPattern] = [:]

    /// Adds a URL pattern to the scanner.
    ///
    /// - Parameter pattern: The URL pattern to add.
    func add(_ pattern: UrlPattern) {
        patterns[pattern.pattern] = pattern
        trie.add(pattern.pattern)
    }

    /// Scans text for URLs.
    ///
    /// Searches the text for URL patterns and returns information about the first match found.
    ///
    /// - Parameters:
    ///   - text: The text to scan.
    ///   - startIndex: The index to start scanning from.
    ///   - count: The number of characters to scan.
    /// - Returns: A ``UrlMatch`` if a URL was found; otherwise, `nil`.
    func scan(_ text: [Character], startIndex: Int, count: Int) -> UrlMatch? {
        let (matchIndex, pattern) = trie.search(text, startIndex: startIndex, count: count)
        guard matchIndex != -1, let pattern, let url = patterns[pattern] else {
            return nil
        }

        var match = UrlMatch(pattern: url.pattern, prefix: url.prefix)
        let endIndex = startIndex + count

        let getStartIndex: (inout UrlMatch, [Character], Int, Int, Int) -> Bool
        let getEndIndex: (inout UrlMatch, [Character], Int, Int, Int) -> Bool

        switch url.type {
        case .addrspec:
            getStartIndex = Self.getAddrspecStartIndex
            getEndIndex = Self.getAddrspecEndIndex
        case .mailto:
            getStartIndex = Self.getMailToStartIndex
            getEndIndex = Self.getMailToEndIndex
        case .file:
            getStartIndex = Self.getFileStartIndex
            getEndIndex = Self.getFileEndIndex
        case .web:
            getStartIndex = Self.getWebStartIndex
            getEndIndex = Self.getWebEndIndex
        }

        if !getStartIndex(&match, text, startIndex, matchIndex, endIndex) {
            return nil
        }

        if !getEndIndex(&match, text, startIndex, matchIndex, endIndex) {
            return nil
        }

        return match
    }

    private static func getClosingBrace(_ match: UrlMatch, _ text: [Character], _ startIndex: Int) -> Character {
        if match.startIndex == startIndex {
            return "\0"
        }

        switch text[match.startIndex - 1] {
        case "(": return ")"
        case "{": return "}"
        case "[": return "]"
        case "<": return ">"
        case "|": return "|"
        default: return "\0"
        }
    }

    private static func asciiValue(_ c: Character) -> UInt32 {
        c.unicodeScalars.first?.value ?? 0
    }

    private static func isDigit(_ c: Character) -> Bool {
        let v = asciiValue(c)
        return v >= 48 && v <= 57
    }

    private static func isLetterOrDigit(_ c: Character) -> Bool {
        let v = asciiValue(c)
        return (v >= 65 && v <= 90) || (v >= 97 && v <= 122) || isDigit(c)
    }

    private static func isUrlSafe(_ c: Character) -> Bool {
        let v = asciiValue(c)
        return v >= 128 || isLetterOrDigit(c) || urlSafeCharacterSet.contains(c)
    }

    private static func isAtom(_ c: Character) -> Bool {
        let v = asciiValue(c)
        return v >= 128 || isLetterOrDigit(c) || atomCharacterSet.contains(c)
    }

    private static func isDomain(_ c: Character) -> Bool {
        let v = asciiValue(c)
        return v >= 128 || isLetterOrDigit(c) || c == "-"
    }

    private static func skipAtom(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        let startIndex = index
        while index < endIndex, isAtom(text[index]) {
            index += 1
        }
        return index > startIndex
    }

    private static func skipAtomBackwards(_ text: [Character], _ startIndex: Int, _ index: inout Int) -> Bool {
        guard isAtom(text[index]) else {
            return false
        }

        while index > startIndex, isAtom(text[index - 1]) {
            index -= 1
        }
        return true
    }

    private static func skipSubDomain(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        guard isDomain(text[index]), text[index] != "-" else {
            return false
        }

        index += 1
        while index < endIndex, isDomain(text[index]) {
            index += 1
        }

        return true
    }

    private static func skipDomain(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        guard skipSubDomain(text, endIndex, &index) else {
            return false
        }

        while index < endIndex, text[index] == "." {
            let subdomain = index
            index += 1

            if index == endIndex || !skipSubDomain(text, endIndex, &index) {
                index = subdomain
                break
            }
        }

        return true
    }

    private static func skipQuoted(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        var escaped = false
        index += 1

        while index < endIndex {
            if text[index] == "\\" {
                escaped.toggle()
            } else if !escaped {
                if text[index] == "\"" {
                    break
                }
            } else {
                escaped = false
            }
            index += 1
        }

        guard index < endIndex, text[index] == "\"" else {
            return false
        }

        index += 1
        return true
    }

    private static func skipQuotedBackwards(_ text: [Character], _ startIndex: Int, _ index: inout Int) -> Bool {
        index -= 1

        while index >= startIndex {
            if text[index] == "\"" {
                if index == startIndex || text[index - 1] != "\\" {
                    break
                }
            }
            index -= 1
        }

        return index >= startIndex && text[index] == "\""
    }

    private static func skipWord(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        if text[index] == "\"" {
            return skipQuoted(text, endIndex, &index)
        }
        return skipAtom(text, endIndex, &index)
    }

    private static func skipWordBackwards(_ text: [Character], _ startIndex: Int, _ index: inout Int) -> Bool {
        if text[index] == "\"" {
            return skipQuotedBackwards(text, startIndex, &index)
        }
        return skipAtomBackwards(text, startIndex, &index)
    }

    private static func skipIPv4Literal(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        var groups = 0

        while index < endIndex, groups < 4 {
            let start = index
            var value = 0

            while index < endIndex {
                let v = asciiValue(text[index])
                if v < 48 || v > 57 {
                    break
                }
                value = (value * 10) + Int(v - 48)
                index += 1
            }

            if index == start || index - start > 3 || value > 255 {
                return false
            }

            groups += 1
            if groups < 4, index < endIndex, text[index] == "." {
                index += 1
            }
        }

        return groups == 4
    }

    private static func isHexDigit(_ c: Character) -> Bool {
        let v = asciiValue(c)
        return (v >= 65 && v <= 70) || (v >= 97 && v <= 102) || (v >= 48 && v <= 57)
    }

    private static func isIPv6(_ text: [Character], _ startIndex: Int) -> Bool {
        guard startIndex + 4 < text.count else {
            return false
        }
        let i = startIndex
        let c0 = text[i]
        let c1 = text[i + 1]
        let c2 = text[i + 2]
        let c3 = text[i + 3]
        let c4 = text[i + 4]

        let isIP = (c0 == "I" || c0 == "i") && (c1 == "P" || c1 == "p") && (c2 == "V" || c2 == "v")
        return isIP && c3 == "6" && c4 == ":"
    }

    private static func skipIPv6Literal(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        var compact = false
        var colons = 0

        while index < endIndex {
            let start = index

            while index < endIndex, isHexDigit(text[index]) {
                index += 1
            }

            if index >= endIndex {
                break
            }

            if index > start, colons > 2, text[index] == "." {
                index = start
                if !skipIPv4Literal(text, endIndex, &index) {
                    return false
                }
                return compact ? colons < 6 : colons == 6
            }

            let count = index - start
            if count > 4 {
                return false
            }

            if text[index] != ":" {
                break
            }

            let colonStart = index
            while index < endIndex, text[index] == ":" {
                index += 1
            }

            let colonCount = index - colonStart
            if colonCount > 2 {
                return false
            }

            if colonCount == 2 {
                if compact {
                    return false
                }
                compact = true
                colons += 2
            } else {
                colons += 1
            }
        }

        if colons < 2 {
            return false
        }

        return compact ? colons < 7 : colons == 7
    }

    private static func getAddrspecStartIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        var index = matchIndex - 1
        if matchIndex == startIndex {
            return false
        }

        repeat {
            if !skipWordBackwards(text, startIndex, &index) {
                return false
            }

            if index == startIndex {
                break
            }

            if text[index - 1] != "." {
                break
            }

            index -= 2

            if index <= startIndex {
                return false
            }
        } while true

        match.startIndex = index
        return true
    }

    private static func getAddrspecEndIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        var index = matchIndex + 1
        if index == endIndex {
            return false
        }

        if text[index] != "[" {
            if !skipDomain(text, endIndex, &index) {
                return false
            }
            match.endIndex = index
            return true
        }

        index += 1
        if index + 8 >= endIndex {
            return false
        }

        if isIPv6(text, index) {
            index += 5
            if !skipIPv6Literal(text, endIndex, &index) {
                return false
            }
        } else {
            if !skipIPv4Literal(text, endIndex, &index) {
                return false
            }
        }

        if index >= endIndex || text[index] != "]" {
            return false
        }
        index += 1

        match.endIndex = index
        return true
    }

    private static func getFileStartIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        match.startIndex = matchIndex
        return true
    }

    private static func getFileEndIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        let close = getClosingBrace(match, text, startIndex)
        var index = matchIndex + match.pattern.count

        while index < endIndex, isUrlSafe(text[index]), text[index] != close {
            index += 1
        }

        match.endIndex = index
        return index > matchIndex + match.pattern.count
    }

    private static func getMailToStartIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        match.startIndex = matchIndex
        return true
    }

    private static func skipAddrspec(_ text: [Character], _ endIndex: Int, _ index: inout Int) -> Bool {
        guard skipWord(text, endIndex, &index), index < endIndex else {
            return false
        }

        while text[index] == "." {
            index += 1
            if index >= endIndex {
                return false
            }
            if !skipWord(text, endIndex, &index) {
                return false
            }
            if index >= endIndex {
                return false
            }
        }

        if index + 1 >= endIndex || text[index] != "@" {
            return false
        }
        index += 1

        if text[index] != "[" {
            if !skipDomain(text, endIndex, &index) {
                return false
            }
        } else {
            index += 1
            if index + 8 >= endIndex {
                return false
            }

            if isIPv6(text, index) {
                index += 5
                if !skipIPv6Literal(text, endIndex, &index) {
                    return false
                }
            } else {
                if !skipIPv4Literal(text, endIndex, &index) {
                    return false
                }
            }

            if index >= endIndex || text[index] != "]" {
                return false
            }
            index += 1
        }

        return true
    }

    private static func getMailToEndIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        let close = getClosingBrace(match, text, startIndex)
        let contentIndex = matchIndex + match.pattern.count
        var index = contentIndex

        if contentIndex >= endIndex {
            return false
        }

        if !skipAddrspec(text, endIndex, &index) {
            index = contentIndex
        }

        if index < endIndex, text[index] == "?" {
            index += 1
            while index < endIndex, isUrlSafe(text[index]), text[index] != close {
                index += 1
            }
        }

        match.endIndex = index
        return index > contentIndex
    }

    private static func getWebStartIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        match.startIndex = matchIndex
        return true
    }

    private static func getWebEndIndex(_ match: inout UrlMatch, _ text: [Character], _ startIndex: Int, _ matchIndex: Int, _ endIndex: Int) -> Bool {
        let close = getClosingBrace(match, text, startIndex)
        var index = matchIndex + match.pattern.count

        if index >= endIndex || !skipDomain(text, endIndex, &index) {
            return false
        }

        if index + 1 < endIndex, text[index] == ":", isDigit(text[index + 1]) {
            index += 2
            while index < endIndex, isDigit(text[index]) {
                index += 1
            }
        }

        if index < endIndex, text[index] == "/" || text[index] == "?" {
            if text[index] == "/" {
                index += 1
            }

            while index < endIndex, text[index] != close {
                if text[index] == "?" || text[index] == "&" {
                    if index + 1 >= endIndex || !isLetterOrDigit(text[index + 1]) {
                        break
                    }
                    index += 1
                } else if !isUrlSafe(text[index]) {
                    break
                }
                index += 1
            }
        }

        match.endIndex = index
        return true
    }
}
