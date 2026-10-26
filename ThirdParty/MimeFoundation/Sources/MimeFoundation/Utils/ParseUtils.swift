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
// ParseUtils.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Internal utility methods for parsing MIME tokens and syntax elements.
///
/// `ParseUtils` provides low-level parsing primitives used throughout the
/// MIME parser. These methods operate on byte buffers and handle common
/// parsing tasks like skipping whitespace, parsing integers, and extracting
/// tokens according to RFC 822/2822 rules.
///
/// ## Common Operations
///
/// - Integer parsing: ``tryParseInt32(_:index:endIndex:value:)``
/// - Whitespace handling: ``skipWhiteSpace(_:index:endIndex:)``
/// - Comment handling: ``skipComment(_:index:endIndex:)-9k8lt``
/// - Token extraction: ``skipAtom(_:index:endIndex:)``, ``skipToken(_:index:endIndex:)``
/// - Domain parsing: ``tryParseDomain(_:index:endIndex:sentinels:throwOnError:domain:)``
/// - Message-ID parsing: ``tryParseMsgId(_:index:endIndex:requireAngleAddr:throwOnError:msgid:)``
enum ParseUtils {
    /// Attempts to parse a 32-bit integer from a byte buffer.
    ///
    /// Parses decimal digits from the buffer starting at the current index,
    /// advancing the index past all consecutive digits. Checks for integer
    /// overflow and returns `false` if the value would exceed `Int32.max`.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the last digit on success.
    ///   - endIndex: The end of the valid range in the buffer.
    ///   - value: On success, contains the parsed integer value.
    /// - Returns: `true` if at least one digit was parsed; `false` if no digits
    ///   were found or if overflow would occur.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let buffer = Array("123abc".utf8)
    /// var index = 0
    /// var value = 0
    /// if ParseUtils.tryParseInt32(buffer, index: &index, endIndex: buffer.count, value: &value) {
    ///     print(value)  // 123
    ///     print(index)  // 3
    /// }
    /// ```
    static func tryParseInt32(_ text: [UInt8], index: inout Int, endIndex: Int, value: inout Int) -> Bool {
        let startIndex = index
        value = 0

        while index < endIndex {
            let byte = text[index]
            if byte < 0x30 || byte > 0x39 {
                break
            }
            let digit = Int(byte - 0x30)
            if value > Int(Int32.max) / 10 {
                return false
            }
            if value == Int(Int32.max) / 10 && digit > Int(Int32.max % 10) {
                return false
            }
            value = (value * 10) + digit
            index += 1
        }

        return index > startIndex
    }

    /// Skips whitespace characters in a byte buffer.
    ///
    /// Advances the index past all consecutive whitespace characters
    /// (space, tab, carriage return, line feed).
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the last whitespace character.
    ///   - endIndex: The end of the valid range in the buffer.
    /// - Returns: `true` if at least one whitespace character was skipped;
    ///   `false` otherwise.
    static func skipWhiteSpace(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let startIndex = index
        while index < endIndex && ByteClassification.isWhitespace(text[index]) {
            index += 1
        }
        return index > startIndex
    }

    /// Skips an RFC 822 comment in a byte buffer.
    ///
    /// Skips a comment token (text enclosed in parentheses), handling nested
    /// comments and escaped characters. The index must point to an opening
    /// parenthesis before calling this method.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer (at '('). Updated to point
    ///     after the closing ')' on success.
    ///   - endIndex: The end of the valid range in the buffer.
    /// - Returns: `true` if the comment was properly closed; `false` if the
    ///   buffer ended before the comment was closed.
    static func skipComment(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        var escaped = false
        var depth = 1
        index += 1

        while index < endIndex && depth > 0 {
            if text[index] == 0x5C { // '\\'
                escaped.toggle()
            } else if !escaped {
                if text[index] == 0x28 { // '('
                    depth += 1
                } else if text[index] == 0x29 { // ')'
                    depth -= 1
                }
            } else {
                escaped = false
            }
            index += 1
        }

        return depth == 0
    }

    /// Skips an RFC 822 comment in a string.
    ///
    /// String variant of ``skipComment(_:index:endIndex:)-9k8lt`` for parsing
    /// comments from string data.
    ///
    /// - Parameters:
    ///   - text: The string to parse.
    ///   - index: The current position in the string (at '('). Updated to point
    ///     after the closing ')' on success.
    ///   - endIndex: The end of the valid range in the string.
    /// - Returns: `true` if the comment was properly closed; `false` otherwise.
    static func skipComment(_ text: String, index: inout Int, endIndex: Int) -> Bool {
        var escaped = false
        var depth = 1
        index += 1

        while index < endIndex && depth > 0 {
            let ch = text[text.index(text.startIndex, offsetBy: index)]
            if ch == "\\" {
                escaped.toggle()
            } else if !escaped {
                if ch == "(" {
                    depth += 1
                } else if ch == ")" {
                    depth -= 1
                }
            } else {
                escaped = false
            }
            index += 1
        }

        return depth == 0
    }

    /// Skips comments and whitespace in a byte buffer.
    ///
    /// Skips any combination of whitespace and RFC 822 comments. This is
    /// commonly used to skip CFWS (comments and folding whitespace) in
    /// structured headers.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     all comments and whitespace.
    ///   - endIndex: The end of the valid range in the buffer.
    ///   - throwOnError: If `true`, throws ``ParseException`` on incomplete
    ///     comments. If `false`, returns `false` instead.
    /// - Returns: `true` if parsing succeeded; `false` if an error occurred
    ///   and `throwOnError` is `false`.
    /// - Throws: ``ParseException`` if a comment is incomplete and `throwOnError`
    ///   is `true`.
    static func skipCommentsAndWhiteSpace(_ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool) throws -> Bool {
        _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)

        while index < endIndex && text[index] == 0x28 { // '('
            let startIndex = index
            if !skipComment(text, index: &index, endIndex: endIndex) {
                if throwOnError {
                    throw ParseException("Incomplete comment token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
            _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)
        }

        return true
    }

    /// Skips a quoted string in a byte buffer.
    ///
    /// Skips a quoted-string token (text enclosed in double quotes), handling
    /// escaped characters. The index must point to an opening quote before
    /// calling this method.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer (at '"'). Updated to point
    ///     after the closing '"' on success.
    ///   - endIndex: The end of the valid range in the buffer.
    ///   - throwOnError: If `true`, throws ``ParseException`` on incomplete
    ///     quoted strings. If `false`, returns `false` instead.
    /// - Returns: `true` if the quoted string was properly closed; `false` if
    ///   an error occurred and `throwOnError` is `false`.
    /// - Throws: ``ParseException`` if the quoted string is incomplete and
    ///   `throwOnError` is `true`.
    static func skipQuoted(_ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool) throws -> Bool {
        let startIndex = index
        var escaped = false

        index += 1
        while index < endIndex {
            if text[index] == 0x5C { // '\\'
                escaped.toggle()
            } else if !escaped {
                if text[index] == 0x22 { // '"'
                    break
                }
            } else {
                escaped = false
            }
            index += 1
        }

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete quoted-string token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        index += 1
        return true
    }

    /// Skips an atom token in a byte buffer.
    ///
    /// An atom is a sequence of non-special, non-whitespace ASCII characters
    /// as defined by RFC 822. This advances the index past all consecutive
    /// atom characters.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the last atom character.
    ///   - endIndex: The end of the valid range in the buffer.
    /// - Returns: `true` if at least one atom character was skipped; `false`
    ///   otherwise.
    static func skipAtom(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let start = index
        while index < endIndex && ByteClassification.isAtom(text[index]) {
            index += 1
        }
        return index > start
    }

    /// Skips a phrase atom token in a byte buffer.
    ///
    /// A phrase atom is similar to an atom but allows a broader set of
    /// characters suitable for use in RFC 822 phrases (like display names
    /// in email addresses).
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the last phrase atom character.
    ///   - endIndex: The end of the valid range in the buffer.
    /// - Returns: `true` if at least one phrase atom character was skipped;
    ///   `false` otherwise.
    static func skipPhraseAtom(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let start = index
        while index < endIndex && ByteClassification.isPhraseAtom(text[index]) {
            index += 1
        }
        return index > start
    }

    /// Skips a MIME token in a byte buffer.
    ///
    /// A MIME token is a sequence of non-whitespace, non-special characters
    /// as defined by RFC 2045. Tokens are used in MIME headers like
    /// Content-Type and Content-Disposition.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the last token character.
    ///   - endIndex: The end of the valid range in the buffer.
    /// - Returns: `true` if at least one token character was skipped; `false`
    ///   otherwise.
    static func skipToken(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let start = index
        while index < endIndex && ByteClassification.isToken(text[index]) {
            index += 1
        }
        return index > start
    }

    /// Skips an RFC 822 word (atom or quoted-string) in a byte buffer.
    ///
    /// A word is either an atom or a quoted-string. This method determines
    /// which type is present and skips it accordingly.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the word on success.
    ///   - endIndex: The end of the valid range in the buffer.
    ///   - throwOnError: If `true`, throws ``ParseException`` on incomplete
    ///     quoted strings. If `false`, returns `false` instead.
    /// - Returns: `true` if a word was successfully skipped; `false` if no
    ///   word was found or an error occurred.
    /// - Throws: ``ParseException`` if the word is incomplete and `throwOnError`
    ///   is `true`.
    static func skipWord(_ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool) throws -> Bool {
        if text[index] == 0x22 {
            return try skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)
        }
        if ByteClassification.isAtom(text[index]) {
            return skipAtom(text, index: &index, endIndex: endIndex)
        }
        return false
    }

    /// Checks if a byte value is in a list of sentinel characters.
    ///
    /// Sentinel characters mark boundaries in parsing, such as the end of
    /// a token or the beginning of a special construct.
    ///
    /// - Parameters:
    ///   - c: The byte to check.
    ///   - sentinels: The array of sentinel byte values.
    /// - Returns: `true` if `c` is in the sentinel array; `false` otherwise.
    static func isSentinel(_ c: UInt8, _ sentinels: [UInt8]) -> Bool {
        for sentinel in sentinels where c == sentinel {
            return true
        }
        return false
    }

    private static func tryParseDotAtom(
        _ text: [UInt8],
        index: inout Int,
        endIndex: Int,
        sentinels: [UInt8],
        throwOnError: Bool,
        tokenType: String,
        dotAtom: inout String?
    ) throws -> Bool {
        var token = ValueStringBuilder(initialCapacity: 128)
        let startIndex = index
        var comment = 0
        dotAtom = nil

        repeat {
            if !ByteClassification.isAtom(text[index]) {
                if throwOnError {
                    throw ParseException("Invalid \(tokenType) token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            let start = index
            while index < endIndex && ByteClassification.isAtom(text[index]) {
                index += 1
            }

            do {
                let value = try CharsetUtils.getString(text, start: start, length: index - start, encoding: .utf8)
                token.append(value)
            } catch {
                if throwOnError {
                    throw ParseException("Internationalized \(tokenType)s may only contain UTF-8 characters.", tokenIndex: start, errorIndex: start)
                }
                return false
            }

            comment = index
            if !(try skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex || text[index] != 0x2E { // '.'
                index = comment
                break
            }

            index += 1
            if !(try skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex || isSentinel(text[index], sentinels) {
                break
            }

            token.append(".")
        } while true

        dotAtom = token.asString()
        return true
    }

    /// Internal helper to parse a domain literal (e.g., `[127.0.0.1]`).
    private static func tryParseDomainLiteral(_ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool, domain: inout String?) throws -> Bool {
        var token = ValueStringBuilder(initialCapacity: 128)
        let startIndex = index
        domain = nil

        index += 1
        token.append("[")
        _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)

        repeat {
            while index < endIndex && ByteClassification.isDomain(text[index]) {
                token.append(Character(UnicodeScalar(text[index])))
                index += 1
            }

            _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)

            if index >= endIndex {
                if throwOnError {
                    throw ParseException("Incomplete domain literal token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            if text[index] == 0x5D { // ']'
                break
            }

            if !ByteClassification.isDomain(text[index]) {
                if throwOnError {
                    throw ParseException("Invalid domain literal token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
        } while true

        token.append("]")
        index += 1
        domain = token.asString()
        return true
    }

    /// Attempts to parse a domain from a byte buffer.
    ///
    /// Parses either a domain literal (e.g., `[127.0.0.1]`) or a dot-atom
    /// domain name (e.g., `example.com`). This is used when parsing email
    /// addresses and Message-IDs.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the domain on success.
    ///   - endIndex: The end of the valid range in the buffer.
    ///   - sentinels: Byte values that mark the end of the domain.
    ///   - throwOnError: If `true`, throws ``ParseException`` on parse errors.
    ///     If `false`, returns `false` instead.
    ///   - domain: On success, contains the parsed domain string.
    /// - Returns: `true` if a domain was successfully parsed; `false` if no
    ///   domain was found or an error occurred.
    /// - Throws: ``ParseException`` if parsing fails and `throwOnError` is `true`.
    static func tryParseDomain(_ text: [UInt8], index: inout Int, endIndex: Int, sentinels: [UInt8], throwOnError: Bool, domain: inout String?) throws -> Bool {
        if text[index] == 0x5B {
            return try tryParseDomainLiteral(text, index: &index, endIndex: endIndex, throwOnError: throwOnError, domain: &domain)
        }

        return try tryParseDotAtom(text, index: &index, endIndex: endIndex, sentinels: sentinels, throwOnError: throwOnError, tokenType: "domain", dotAtom: &domain)
    }

    /// Attempts to parse a Message-ID from a byte buffer.
    ///
    /// Parses an RFC 822 msg-id token, which has the format:
    /// ```
    /// <local-part@domain>
    /// ```
    ///
    /// or, when `requireAngleAddr` is `false`, just:
    /// ```
    /// local-part@domain
    /// ```
    ///
    /// This is used to parse Message-ID and Content-ID headers, as well as
    /// references in In-Reply-To and References headers.
    ///
    /// - Parameters:
    ///   - text: The byte buffer to parse.
    ///   - index: The current position in the buffer. Updated to point after
    ///     the Message-ID on success.
    ///   - endIndex: The end of the valid range in the buffer.
    ///   - requireAngleAddr: If `true`, requires the Message-ID to be enclosed
    ///     in angle brackets. If `false`, accepts both forms.
    ///   - throwOnError: If `true`, throws ``ParseException`` on parse errors.
    ///     If `false`, returns `false` instead.
    ///   - msgid: On success, contains the parsed Message-ID string (without
    ///     angle brackets).
    /// - Returns: `true` if a Message-ID was successfully parsed; `false` if
    ///   no Message-ID was found or an error occurred.
    /// - Throws: ``ParseException`` if parsing fails and `throwOnError` is `true`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let buffer = Array("<abc123@example.com>".utf8)
    /// var index = 0
    /// var msgid: String?
    /// if try ParseUtils.tryParseMsgId(buffer, index: &index, endIndex: buffer.count,
    ///                                  requireAngleAddr: true, throwOnError: false, msgid: &msgid) {
    ///     print(msgid!)  // "abc123@example.com"
    /// }
    /// ```
    static func tryParseMsgId(_ text: [UInt8], index: inout Int, endIndex: Int, requireAngleAddr: Bool, throwOnError: Bool, msgid: inout String?) throws -> Bool {
        var squareBrackets = false
        var angleAddr = false
        msgid = nil

        if !(try skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex || (requireAngleAddr && text[index] != 0x3C) {
            if throwOnError {
                throw ParseException("No msg-id token found.", tokenIndex: index, errorIndex: index)
            }
            return false
        }

        let tokenIndex = index

        if text[index] == 0x3C {
            angleAddr = true
            index += 1
        }

        _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete msg-id token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
            }
            return false
        }

        var token = ValueStringBuilder(initialCapacity: 128)

        if text[index] == 0x5B {
            squareBrackets = true
        }

        repeat {
            let start = index

            if text[index] == 0x22 {
                if !(try skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }
            } else {
                while index < endIndex && text[index] != 0x2E && text[index] != 0x40 && text[index] != 0x3E && !ByteClassification.isWhitespace(text[index]) {
                    index += 1
                }
            }

            do {
                let word = try CharsetUtils.getString(text, start: start, length: index - start, encoding: .utf8)
                token.append(word)
            } catch {
                if throwOnError {
                    throw ParseException("Internationalized local-part tokens may only contain UTF-8 characters.", tokenIndex: start, errorIndex: start)
                }
                return false
            }

            _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)

            if index >= endIndex {
                if angleAddr {
                    if throwOnError {
                        throw ParseException("Incomplete msg-id at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                    }
                    return false
                }
                break
            }

            if text[index] == 0x40 || text[index] == 0x3E {
                break
            }

            if text[index] == 0x2E {
                token.append(".")
                index += 1
                _ = skipWhiteSpace(text, index: &index, endIndex: endIndex)
            }

            if index >= endIndex {
                if throwOnError {
                    throw ParseException("Incomplete msg-id at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                }
                return false
            }
        } while true

        if index < endIndex && text[index] == 0x40 {
            token.append("@")
            index += 1

            while index < endIndex && text[index] == 0x40 {
                index += 1
            }

            if !(try skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index < endIndex && text[index] != 0x3E {
                repeat {
                    var domain: String? = nil
                    if !(try tryParseDomain(text, index: &index, endIndex: endIndex, sentinels: [0x3E, 0x40], throwOnError: throwOnError, domain: &domain)) {
                        return false
                    }

                    if let domainValue = domain {
                        var decodedDomain = domainValue
                        if isIdnEncoded(decodedDomain) {
                            decodedDomain = MailboxAddress.idnMapping.decode(decodedDomain)
                        }
                        token.append(decodedDomain)
                    }

                    if index >= endIndex || text[index] != 0x40 {
                        break
                    }

                    token.append("@")
                    index += 1
                } while true

                if !(try skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }
            }
        }

        if squareBrackets && index < endIndex && text[index] == 0x5D {
            token.append("]")
            index += 1
        }

        if angleAddr && (index >= endIndex || text[index] != 0x3E) {
            if throwOnError {
                throw ParseException("Incomplete msg-id token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
            }
            return false
        }

        if index < endIndex && text[index] == 0x3E {
            index += 1
        }

        msgid = token.asString()
        return true
    }

    /// Checks if a string contains international (non-ASCII) characters.
    ///
    /// Determines whether the specified range of a string contains any
    /// characters with Unicode scalar values greater than 127.
    ///
    /// - Parameters:
    ///   - value: The string to check.
    ///   - startIndex: The starting index in the string.
    ///   - count: The number of characters to check.
    /// - Returns: `true` if any non-ASCII characters are found; `false` if
    ///   all characters are ASCII (0-127).
    static func isInternational(_ value: String, startIndex: Int, count: Int) -> Bool {
        let endIndex = startIndex + count
        let scalars = Array(value.unicodeScalars)
        guard startIndex >= 0, count >= 0, endIndex <= scalars.count else {
            return false
        }
        for i in startIndex..<endIndex {
            if scalars[i].value > 127 {
                return true
            }
        }
        return false
    }

    /// Checks if a string contains international characters from a starting index.
    ///
    /// - Parameters:
    ///   - value: The string to check.
    ///   - startIndex: The starting index in the string.
    /// - Returns: `true` if any non-ASCII characters are found from the starting
    ///   index to the end of the string; `false` otherwise.
    static func isInternational(_ value: String, startIndex: Int) -> Bool {
        return isInternational(value, startIndex: startIndex, count: value.unicodeScalars.count - startIndex)
    }

    /// Checks if a string contains any international characters.
    ///
    /// - Parameter value: The string to check.
    /// - Returns: `true` if any non-ASCII characters are found; `false` if
    ///   the string is pure ASCII.
    static func isInternational(_ value: String) -> Bool {
        return isInternational(value, startIndex: 0, count: value.unicodeScalars.count)
    }

    /// Checks if a domain name is IDN-encoded (Internationalized Domain Name).
    ///
    /// Determines whether a domain name uses Punycode encoding (starts with
    /// "xn--" or contains ".xn--") which indicates an internationalized domain
    /// name encoded in ASCII-compatible form.
    ///
    /// - Parameter value: The domain name to check.
    /// - Returns: `true` if the domain is IDN-encoded; `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// ParseUtils.isIdnEncoded("xn--e28h.com")  // true
    /// ParseUtils.isIdnEncoded("example.com")   // false
    /// ParseUtils.isIdnEncoded("mail.xn--e28h.com")  // true
    /// ```
    static func isIdnEncoded(_ value: String) -> Bool {
        if value.hasPrefix("xn--") {
            return true
        }
        return value.range(of: ".xn--") != nil
    }
}
