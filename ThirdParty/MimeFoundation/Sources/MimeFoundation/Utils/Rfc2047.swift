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
// Rfc2047.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Utility methods for encoding and decoding RFC 2047 encoded-word tokens.
///
/// RFC 2047 defines the "encoded-word" mechanism for representing non-ASCII
/// text in email headers. Encoded words have the format:
///
/// ```
/// =?charset?encoding?encoded-text?=
/// ```
///
/// Where:
/// - `charset` is the character encoding (e.g., "utf-8", "iso-8859-1")
/// - `encoding` is either "B" (Base64) or "Q" (Quoted-Printable)
/// - `encoded-text` is the actual encoded content
///
/// ## Decoding
///
/// Use the ``decodePhrase(_:)-7fj0j`` or ``decodeText(_:)-2nrfy`` methods to decode
/// RFC 2047 encoded headers:
///
/// ```swift
/// let encoded = Array("=?utf-8?B?SGVsbG8gV29ybGQ=?=".utf8)
/// let decoded = Rfc2047.decodePhrase(encoded)
/// // "Hello World"
/// ```
///
/// ## Encoding
///
/// Use the ``encodePhrase(_:_:)-5e8il`` or ``encodeText(_:_:)-8edqo`` methods to
/// encode non-ASCII text for use in headers:
///
/// ```swift
/// let text = "Hëllö Wörld"
/// let encoded = Rfc2047.encodePhrase(.utf8, text)
/// // Returns: =?utf-8?Q?H=C3=ABll=C3=B6_W=C3=B6rld?=
/// ```
///
/// ## Phrase vs Text
///
/// - **Phrase**: Used for structured headers like From, To, Subject. Allows
///   quoted strings and atoms. Use for RFC 822 "phrase" tokens.
/// - **Text**: Used for unstructured headers like Subject when not in a phrase
///   context. Simpler encoding rules.
enum Rfc2047 {

    /// Decodes an RFC 2047 encoded phrase from a byte buffer.
    ///
    /// Decodes an RFC 2047 encoded phrase (such as those found in From, To, Cc,
    /// and other address headers) using default parser options.
    ///
    /// - Parameter phrase: The byte buffer containing the encoded phrase.
    /// - Returns: The decoded string.
    static func decodePhrase(_ phrase: [UInt8]) -> String {
        decodePhrase(ParserOptions.default, phrase, startIndex: 0, count: phrase.count)
    }

    /// Decodes a portion of an RFC 2047 encoded phrase from a byte buffer.
    ///
    /// - Parameters:
    ///   - phrase: The byte buffer containing the encoded phrase.
    ///   - startIndex: The starting index in the buffer.
    ///   - count: The number of bytes to decode.
    /// - Returns: The decoded string.
    static func decodePhrase(_ phrase: [UInt8], startIndex: Int, count: Int) -> String {
        decodePhrase(ParserOptions.default, phrase, startIndex: startIndex, count: count)
    }

    /// Decodes an RFC 2047 encoded phrase with custom parser options.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - phrase: The byte buffer containing the encoded phrase.
    /// - Returns: The decoded string.
    static func decodePhrase(_ options: ParserOptions, _ phrase: [UInt8]) -> String {
        decodePhrase(options, phrase, startIndex: 0, count: phrase.count)
    }

    /// Decodes a portion of an RFC 2047 encoded phrase with custom parser options.
    ///
    /// Decodes an RFC 2047 encoded phrase (such as those found in From, To, Cc,
    /// and other address headers) from the specified buffer range.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - phrase: The byte buffer containing the encoded phrase.
    ///   - startIndex: The starting index in the buffer.
    ///   - count: The number of bytes to decode.
    /// - Returns: The decoded string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let encoded = Array("=?utf-8?B?SGVsbG8=?=".utf8)
    /// let decoded = Rfc2047.decodePhrase(encoded, startIndex: 0, count: encoded.count)
    /// // "Hello"
    /// ```
    static func decodePhrase(_ options: ParserOptions, _ phrase: [UInt8], startIndex: Int, count: Int) -> String {
        var counts: [Int: Int] = [:]
        var order: [Int] = []
        return decode(options, phrase, startIndex: startIndex, count: count, ignoreWhitespaceBetweenEncodedWords: true, codepageCounts: &counts, codepageOrder: &order)
    }

    static func decodePhrase(_ options: ParserOptions, _ phrase: [UInt8], startIndex: Int, count: Int, codepage: inout Int) -> String {
        var counts: [Int: Int] = [:]
        var order: [Int] = []
        let result = decode(options, phrase, startIndex: startIndex, count: count, ignoreWhitespaceBetweenEncodedWords: true, codepageCounts: &counts, codepageOrder: &order)
        codepage = mostCommonCodepage(counts: counts, order: order)
        return result
    }

    /// Decodes RFC 2047 encoded text from a byte buffer.
    ///
    /// Decodes RFC 2047 encoded text (such as that found in unstructured
    /// headers like Subject) using default parser options.
    ///
    /// - Parameter text: The byte buffer containing the encoded text.
    /// - Returns: The decoded string.
    static func decodeText(_ text: [UInt8]) -> String {
        decodeText(ParserOptions.default, text, startIndex: 0, count: text.count)
    }

    /// Decodes a portion of RFC 2047 encoded text from a byte buffer.
    ///
    /// - Parameters:
    ///   - text: The byte buffer containing the encoded text.
    ///   - startIndex: The starting index in the buffer.
    ///   - count: The number of bytes to decode.
    /// - Returns: The decoded string.
    static func decodeText(_ text: [UInt8], startIndex: Int, count: Int) -> String {
        decodeText(ParserOptions.default, text, startIndex: startIndex, count: count)
    }

    /// Decodes RFC 2047 encoded text with custom parser options.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - text: The byte buffer containing the encoded text.
    /// - Returns: The decoded string.
    static func decodeText(_ options: ParserOptions, _ text: [UInt8]) -> String {
        decodeText(options, text, startIndex: 0, count: text.count)
    }

    /// Decodes a portion of RFC 2047 encoded text with custom parser options.
    ///
    /// Decodes RFC 2047 encoded text (such as that found in unstructured
    /// headers like Subject) from the specified buffer range.
    ///
    /// - Parameters:
    ///   - options: The parser options to use.
    ///   - text: The byte buffer containing the encoded text.
    ///   - startIndex: The starting index in the buffer.
    ///   - count: The number of bytes to decode.
    /// - Returns: The decoded string.
    static func decodeText(_ options: ParserOptions, _ text: [UInt8], startIndex: Int, count: Int) -> String {
        var counts: [Int: Int] = [:]
        var order: [Int] = []
        return decode(options, text, startIndex: startIndex, count: count, ignoreWhitespaceBetweenEncodedWords: true, codepageCounts: &counts, codepageOrder: &order)
    }

    static func decodeText(_ options: ParserOptions, _ text: [UInt8], startIndex: Int, count: Int, codepage: inout Int) -> String {
        var counts: [Int: Int] = [:]
        var order: [Int] = []
        let result = decode(options, text, startIndex: startIndex, count: count, ignoreWhitespaceBetweenEncodedWords: true, codepageCounts: &counts, codepageOrder: &order)
        codepage = mostCommonCodepage(counts: counts, order: order)
        return result
    }

    private struct EncodedWordPayload {
        let charset: String
        let encodingChar: Character
        let payload: [UInt8]
    }

    private static func decode(_ options: ParserOptions, _ input: [UInt8], startIndex: Int, count: Int, ignoreWhitespaceBetweenEncodedWords: Bool, codepageCounts: inout [Int: Int], codepageOrder: inout [Int]) -> String {
        guard count > 0, startIndex >= 0, startIndex + count <= input.count else {
            return ""
        }

        var output = ValueStringBuilder(initialCapacity: count)
        var index = startIndex
        let endIndex = startIndex + count
        var pendingWhitespace = ""
        var lastWasEncoded = false
        var pendingEncoded: EncodedWordPayload? = nil

        func decodePayload(_ word: EncodedWordPayload) -> String {
            let decodedBytes: [UInt8]
            switch word.encodingChar.lowercased() {
            case "q":
                let decoder = QuotedPrintableDecoder(rfc2047: true)
                let outputLength = decoder.estimateOutputLength(word.payload.count)
                var output = Array(repeating: UInt8(0), count: outputLength)
                let written = (try? decoder.decode(word.payload, startIndex: 0, length: word.payload.count, output: &output)) ?? 0
                decodedBytes = Array(output.prefix(written))
            case "b":
                let decoder = Base64Decoder()
                let outputLength = decoder.estimateOutputLength(word.payload.count)
                var output = Array(repeating: UInt8(0), count: outputLength)
                let written = (try? decoder.decode(word.payload, startIndex: 0, length: word.payload.count, output: &output)) ?? 0
                decodedBytes = Array(output.prefix(written))
            default:
                decodedBytes = word.payload
            }

            let encoding = CharsetUtils.getEncoding(word.charset) ?? options.charsetEncoding
            if let decoded = String(data: Data(decodedBytes), encoding: encoding) {
                let codepage = CharsetUtils.getCodepage(encoding)
                codepageCounts[codepage, default: 0] += decodedBytes.count
                if !codepageOrder.contains(codepage) {
                    codepageOrder.append(codepage)
                }
                return decoded
            }
            if let decoded = String(data: Data(decodedBytes), encoding: options.charsetEncoding) {
                let codepage = CharsetUtils.getCodepage(options.charsetEncoding)
                codepageCounts[codepage, default: 0] += decodedBytes.count
                if !codepageOrder.contains(codepage) {
                    codepageOrder.append(codepage)
                }
                return decoded
            }
            if let decoded = String(data: Data(decodedBytes), encoding: .isoLatin1) {
                let codepage = CharsetUtils.getCodepage(.isoLatin1)
                codepageCounts[codepage, default: 0] += decodedBytes.count
                if !codepageOrder.contains(codepage) {
                    codepageOrder.append(codepage)
                }
                return decoded
            }
            return String(decoding: decodedBytes, as: UTF8.self)
        }

        func flushPendingEncoded() {
            guard let pending = pendingEncoded else { return }
            output.append(decodePayload(pending))
            pendingEncoded = nil
        }

        while index < endIndex {
            let byte = input[index]
            if ByteClassification.isWhitespace(byte) {
                let wsStart = index
                index += 1
                while index < endIndex && ByteClassification.isWhitespace(input[index]) {
                    index += 1
                }
                let wsBytes = Array(input[wsStart..<index])
                if let ws = String(bytes: wsBytes, encoding: .ascii) {
                    pendingWhitespace.append(ws)
                }
                continue
            }

            if let decoded = tryDecodeEncodedWord(options, input, index: index, endIndex: endIndex, consumed: &index) {
                if !pendingWhitespace.isEmpty {
                    if !lastWasEncoded || !ignoreWhitespaceBetweenEncodedWords {
                        output.append(pendingWhitespace)
                    }
                    pendingWhitespace = ""
                }
                if let pending = pendingEncoded {
                    if pending.charset.caseInsensitiveCompare(decoded.charset) == .orderedSame &&
                        pending.encodingChar.lowercased() == decoded.encodingChar.lowercased() {
                        let merged = EncodedWordPayload(charset: pending.charset, encodingChar: pending.encodingChar, payload: pending.payload + decoded.payload)
                        pendingEncoded = merged
                    } else {
                        output.append(decodePayload(pending))
                        pendingEncoded = decoded
                    }
                } else {
                    pendingEncoded = decoded
                }
                lastWasEncoded = true
                continue
            }

            if pendingEncoded != nil {
                flushPendingEncoded()
            }

            if !pendingWhitespace.isEmpty {
                output.append(pendingWhitespace)
                pendingWhitespace = ""
            }

            let start = index
            var ascii = true
            while index < endIndex && !ByteClassification.isWhitespace(input[index]) {
                if input[index] == 0x3D, index + 1 < endIndex, input[index + 1] == 0x3F {
                    break
                }
                ascii = ascii && input[index] < 0x80
                index += 1
            }

            let length = index - start
            if length == 0, index < endIndex, input[index] == 0x3D {
                output.append("=")
                index += 1
                lastWasEncoded = false
                continue
            }
            if length > 0 {
                if ascii {
                    if let chunk = String(bytes: input[start..<index], encoding: .ascii) {
                        output.append(chunk)
                    }
                } else {
                    let decoded = CharsetUtils.convertToUnicode(options, input, start: start, length: length)
                    output.append(decoded)
                }
            }
            lastWasEncoded = false
        }

        if pendingEncoded != nil {
            flushPendingEncoded()
        }

        if !pendingWhitespace.isEmpty {
            output.append(pendingWhitespace)
        }

        return output.asString()
    }

    private static func mostCommonCodepage(counts: [Int: Int], order: [Int]) -> Int {
        var best = 65001
        var maxCount = 0
        for codepage in order {
            if let count = counts[codepage], count > maxCount {
                best = codepage
                maxCount = count
            }
        }
        return best
    }

    private static func tryDecodeEncodedWord(_ options: ParserOptions, _ input: [UInt8], index: Int, endIndex: Int, consumed: inout Int) -> EncodedWordPayload? {
        guard index + 2 < endIndex, input[index] == 0x3D, input[index + 1] == 0x3F else {
            return nil
        }

        var cursor = index + 2
        let charsetStart = cursor
        while cursor < endIndex && input[cursor] != 0x3F { // '?'
            cursor += 1
        }
        guard cursor < endIndex else {
            return nil
        }
        let charsetEnd = cursor
        cursor += 1
        guard cursor + 1 < endIndex else {
            return nil
        }
        let encodingByte = input[cursor]
        cursor += 1
        guard input[cursor] == 0x3F else {
            return nil
        }
        cursor += 1
        let encodedTextStart = cursor
        while cursor + 1 < endIndex {
            if input[cursor] == 0x3F && input[cursor + 1] == 0x3D {
                break
            }
            cursor += 1
        }
        guard cursor + 1 < endIndex else {
            return nil
        }
        let encodedTextEnd = cursor
        cursor += 2

        let rawCharsetBytes = Array(input[charsetStart..<charsetEnd])
        guard !rawCharsetBytes.isEmpty else {
            return nil
        }

        var charsetBytes = rawCharsetBytes
        if let starIndex = charsetBytes.firstIndex(of: UInt8(ascii: "*")) {
            if starIndex == 0 {
                return nil
            }
            let languageBytes = charsetBytes[(starIndex + 1)...]
            if languageBytes.isEmpty {
                return nil
            }
            for byte in languageBytes {
                if byte >= 0x80 || !ByteClassification.isAsciiAtom(byte) {
                    return nil
                }
            }
            charsetBytes = Array(charsetBytes[0..<starIndex])
        }

        for byte in charsetBytes {
            if byte >= 0x80 || !ByteClassification.isAsciiAtom(byte) {
                return nil
            }
        }

        guard let charset = String(bytes: charsetBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines), !charset.isEmpty else {
            return nil
        }

        let encodingChar = Character(UnicodeScalar(UInt32(encodingByte))!)
        let lower = encodingChar.lowercased()
        if lower != "q" && lower != "b" {
            return nil
        }
        let payload = Array(input[encodedTextStart..<encodedTextEnd])
        consumed = cursor
        return EncodedWordPayload(charset: charset, encodingChar: encodingChar, payload: payload)
    }

    /// Encodes a phrase for use in MIME headers.
    ///
    /// Encodes the phrase using RFC 2047 encoded-words with the specified
    /// character encoding and default format options.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to use (e.g., `.utf8`).
    ///   - phrase: The text to encode.
    /// - Returns: The encoded phrase as a byte array.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let encoded = Rfc2047.encodePhrase(.utf8, "Hëllö")
    /// // Returns encoded-word format
    /// ```
    static func encodePhrase(_ encoding: String.Encoding, _ phrase: String) -> [UInt8] {
        encodePhrase(FormatOptions.default, encoding, phrase, startIndex: 0, count: phrase.count)
    }

    /// Encodes a substring of a phrase for use in MIME headers.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to use.
    ///   - phrase: The text to encode.
    ///   - startIndex: The starting index in the text.
    ///   - count: The number of characters to encode.
    /// - Returns: The encoded phrase as a byte array.
    static func encodePhrase(_ encoding: String.Encoding, _ phrase: String, startIndex: Int, count: Int) -> [UInt8] {
        encodePhrase(FormatOptions.default, encoding, phrase, startIndex: startIndex, count: count)
    }

    /// Encodes a phrase with custom format options.
    ///
    /// - Parameters:
    ///   - options: The format options controlling line length, character set mixing, etc.
    ///   - encoding: The character encoding to use.
    ///   - phrase: The text to encode.
    /// - Returns: The encoded phrase as a byte array.
    static func encodePhrase(_ options: FormatOptions, _ encoding: String.Encoding, _ phrase: String) -> [UInt8] {
        encodePhrase(options, encoding, phrase, startIndex: 0, count: phrase.count)
    }

    /// Encodes a substring of a phrase with custom format options.
    ///
    /// Encodes a phrase (such as those used in From, To, Cc, and other address
    /// headers) according to RFC 2047 rules.
    ///
    /// - Parameters:
    ///   - options: The format options controlling line length, character set mixing, etc.
    ///   - encoding: The character encoding to use.
    ///   - phrase: The text to encode.
    ///   - startIndex: The starting index in the text.
    ///   - count: The number of characters to encode.
    /// - Returns: The encoded phrase as a byte array.
    static func encodePhrase(_ options: FormatOptions, _ encoding: String.Encoding, _ phrase: String, startIndex: Int, count: Int) -> [UInt8] {
        guard startIndex >= 0, count >= 0, startIndex + count <= phrase.count else {
            return []
        }
        let start = phrase.index(phrase.startIndex, offsetBy: startIndex)
        let end = phrase.index(start, offsetBy: count)
        let substring = String(phrase[start..<end])
        return encodeAsBytes(options, encoding, substring, startIndex: 0, count: substring.utf16.count, type: .phrase)
    }

    /// Encodes text for use in unstructured MIME headers.
    ///
    /// Encodes the text using RFC 2047 encoded-words with the specified
    /// character encoding and default format options.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to use (e.g., `.utf8`).
    ///   - text: The text to encode.
    /// - Returns: The encoded text as a byte array.
    static func encodeText(_ encoding: String.Encoding, _ text: String) -> [UInt8] {
        encodeText(FormatOptions.default, encoding, text, startIndex: 0, count: text.count)
    }

    /// Encodes a substring of text for use in MIME headers.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to use.
    ///   - text: The text to encode.
    ///   - startIndex: The starting index in the text.
    ///   - count: The number of characters to encode.
    /// - Returns: The encoded text as a byte array.
    static func encodeText(_ encoding: String.Encoding, _ text: String, startIndex: Int, count: Int) -> [UInt8] {
        encodeText(FormatOptions.default, encoding, text, startIndex: startIndex, count: count)
    }

    /// Encodes text with custom format options.
    ///
    /// - Parameters:
    ///   - options: The format options controlling line length, character set mixing, etc.
    ///   - encoding: The character encoding to use.
    ///   - text: The text to encode.
    /// - Returns: The encoded text as a byte array.
    static func encodeText(_ options: FormatOptions, _ encoding: String.Encoding, _ text: String) -> [UInt8] {
        encodeText(options, encoding, text, startIndex: 0, count: text.count)
    }

    /// Encodes a substring of text with custom format options.
    ///
    /// Encodes text (such as that used in unstructured headers like Subject)
    /// according to RFC 2047 rules.
    ///
    /// - Parameters:
    ///   - options: The format options controlling line length, character set mixing, etc.
    ///   - encoding: The character encoding to use.
    ///   - text: The text to encode.
    ///   - startIndex: The starting index in the text.
    ///   - count: The number of characters to encode.
    /// - Returns: The encoded text as a byte array.
    static func encodeText(_ options: FormatOptions, _ encoding: String.Encoding, _ text: String, startIndex: Int, count: Int) -> [UInt8] {
        guard startIndex >= 0, count >= 0, startIndex + count <= text.count else {
            return []
        }
        let start = text.index(text.startIndex, offsetBy: startIndex)
        let end = text.index(start, offsetBy: count)
        let substring = String(text[start..<end])
        return encodeAsBytes(options, encoding, substring, startIndex: 0, count: substring.utf16.count, type: .text)
    }

    /// Encodes a phrase and returns the result as a string.
    ///
    /// Similar to ``encodePhrase(_:_:_:)-2lxzq`` but returns a string instead
    /// of a byte array. This is useful when the encoded result will be
    /// immediately used in string contexts.
    ///
    /// - Parameters:
    ///   - options: The format options to use.
    ///   - encoding: The character encoding to use.
    ///   - phrase: The text to encode.
    /// - Returns: The encoded phrase as a string.
    static func encodePhraseAsString(_ options: FormatOptions, _ encoding: String.Encoding, _ phrase: String) -> String {
        encodeAsString(options, encoding, phrase, startIndex: 0, count: phrase.utf16.count, type: .phrase)
    }

    /// Encodes comment text for use in RFC 822 comments.
    ///
    /// Encodes text for use within RFC 822 comment tokens (parenthesized text).
    /// The result is wrapped in parentheses and properly encoded.
    ///
    /// - Parameters:
    ///   - options: The format options to use.
    ///   - encoding: The character encoding to use.
    ///   - text: The comment text to encode.
    ///   - startIndex: The starting index in the text.
    ///   - count: The number of characters to encode.
    /// - Returns: The encoded comment as a string, including parentheses.
    static func encodeComment(_ options: FormatOptions, _ encoding: String.Encoding, _ text: String, startIndex: Int, count: Int) -> String {
        guard startIndex >= 0, count >= 0, startIndex + count <= text.count else {
            return ""
        }
        let start = text.index(text.startIndex, offsetBy: startIndex)
        let end = text.index(start, offsetBy: count)
        let substring = String(text[start..<end])
        return encodeAsString(options, encoding, substring, startIndex: 0, count: substring.utf16.count, type: .comment)
    }

    /// Folds an unstructured header field to fit within line length limits.
    ///
    /// Properly folds long unstructured header values (like Subject) by inserting
    /// line breaks at appropriate points while preserving RFC 2047 encoded-words
    /// and ensuring lines don't exceed the maximum length specified in the format options.
    ///
    /// - Parameters:
    ///   - options: The format options controlling maximum line length and folding.
    ///   - field: The name of the header field being folded (e.g., "Subject").
    ///   - text: The header field value as a byte array.
    /// - Returns: The folded header value as a byte array, with appropriate line breaks.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let longSubject = Array("Very long subject line...".utf8)
    /// let folded = Rfc2047.foldUnstructuredHeader(.default, "Subject", longSubject)
    /// // Returns the text properly folded with CRLF and continuation whitespace
    /// ```
    static func foldUnstructuredHeader(_ options: FormatOptions, _ field: String, _ text: [UInt8]) -> [UInt8] {
        var output = ValueStringBuilder(initialCapacity: text.count + ((text.count / options.maxLineLength) * 2) + 2)
        let folder = TokenFolder(options: options, field: field, input: text)
        tokenizeText(ParserOptions.default, folder, &output, text, startIndex: 0, length: text.count)
        return Array(output.asString().utf8)
    }

    private enum ContentEncoding {
        case base64
        case quotedPrintable
    }

    private enum EncodeType {
        case phrase
        case text
        case comment
    }

    private enum WordType: Int {
        case atom = 0
        case quotedString = 1
        case encodedWord = 2
    }

    private enum WordEncoding: Int {
        case ascii = 0
        case latin1 = 1
        case userSpecified = 2
    }

    private final class Word {
        var type: WordType = .atom
        var startIndex: Int
        var charCount = 0
        var encoding: WordEncoding = .ascii
        var byteCount = 0
        var encodeCount = 0
        var quotedPairs = 0
        var isQuotedStart = false
        var isQuotedEnd = false
        var isCommentStart = false
        var isCommentEnd = false

        init(_ startIndex: Int) {
            self.startIndex = startIndex
        }

        func copy(to other: Word) {
            other.type = type
            other.startIndex = startIndex
            other.charCount = charCount
            other.encoding = encoding
            other.byteCount = byteCount
            other.encodeCount = encodeCount
            other.quotedPairs = quotedPairs
            other.isQuotedStart = isQuotedStart
            other.isQuotedEnd = isQuotedEnd
            other.isCommentStart = isCommentStart
            other.isCommentEnd = isCommentEnd
        }
    }

    private static func maxEncoding(_ lhs: WordEncoding, _ rhs: WordEncoding) -> WordEncoding {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    private static func maxWordType(_ lhs: WordType, _ rhs: WordType) -> WordType {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    private static func isAtom(_ unit: UInt16) -> Bool {
        guard unit < 256 else { return false }
        return ByteClassification.isAtom(UInt8(unit))
    }

    private static func isBlank(_ unit: UInt16) -> Bool {
        unit == 0x20 || unit == 0x09
    }

    private static func isCtrl(_ unit: UInt16) -> Bool {
        guard unit < 256 else { return false }
        return ByteClassification.isCtrl(UInt8(unit))
    }

    private static func isHighSurrogate(_ unit: UInt16) -> Bool {
        unit >= 0xD800 && unit <= 0xDBFF
    }

    private static func isLowSurrogate(_ unit: UInt16) -> Bool {
        unit >= 0xDC00 && unit <= 0xDFFF
    }

    private static func stringFromUtf16(_ units: [UInt16], startIndex: Int, length: Int) -> String {
        guard length > 0 else { return "" }
        let slice = Array(units[startIndex..<(startIndex + length)])
        return String(decoding: slice, as: UTF16.self)
    }

    private static func substring(_ text: String, startIndex: Int, length: Int) -> String {
        guard length > 0 else { return "" }
        let start = String.Index(utf16Offset: startIndex, in: text)
        let end = String.Index(utf16Offset: startIndex + length, in: text)
        return String(text[start..<end])
    }

    private static func estimateEncodedWordLength(_ charset: String, byteCount: Int, encodeCount: Int) -> Int {
        let overhead = charset.count + 7
        if Double(encodeCount) < Double(byteCount) * 0.17 {
            return overhead + (byteCount - encodeCount) + (encodeCount * 3)
        }
        return overhead + ((byteCount + 2) / 3) * 4
    }

    private static func estimateEncodedWordLength(_ encoding: String.Encoding, byteCount: Int, encodeCount: Int) -> Int {
        estimateEncodedWordLength(CharsetUtils.getMimeCharset(encoding), byteCount: byteCount, encodeCount: encodeCount)
    }

    private static func exceedsMaxLineLength(_ options: FormatOptions, _ charset: String.Encoding, _ word: Word) -> Bool {
        let length: Int
        switch word.type {
        case .encodedWord:
            switch word.encoding {
            case .latin1:
                length = estimateEncodedWordLength("iso-8859-1", byteCount: word.byteCount, encodeCount: word.encodeCount)
            case .ascii:
                length = estimateEncodedWordLength("us-ascii", byteCount: word.byteCount, encodeCount: word.encodeCount)
            case .userSpecified:
                length = estimateEncodedWordLength(charset, byteCount: word.byteCount, encodeCount: word.encodeCount)
            }
        case .quotedString:
            length = word.byteCount + word.quotedPairs + 2
        case .atom:
            length = word.byteCount
        }
        return length + 1 >= options.maxLineLength
    }

    private static func getBestContentEncoding(_ bytes: [UInt8]) -> ContentEncoding {
        var count = 0
        for byte in bytes where byte > 127 {
            count += 1
        }
        if Double(count) < Double(bytes.count) * 0.17 {
            return .quotedPrintable
        }
        return .base64
    }

    private static func appendEncodedWord(
        builder: inout ValueStringBuilder,
        encoding: String.Encoding,
        text: String,
        startIndex: Int,
        length: Int,
        mode: QEncodeMode
    ) -> Int {
        let startLength = builder.length
        let substring = substring(text, startIndex: startIndex, length: length)
        var chosenEncoding = encoding
        var data = substring.data(using: chosenEncoding)
        if data == nil {
            chosenEncoding = .utf8
            data = substring.data(using: chosenEncoding)
        }
        let bytes = Array(data ?? Data())
        let useBase64 = charsetRequiresBase64(chosenEncoding) || getBestContentEncoding(bytes) == .base64
        let encoder: any Rfc2047Encoder
        if useBase64 {
            encoder = Rfc2047Base64Encoder()
        } else {
            encoder = Rfc2047QuotedPrintableEncoder(mode: mode)
        }

        let outputLength = encoder.estimateOutputLength(bytes.count)
        var output = Array(repeating: UInt8(0), count: outputLength)
        let written = (try? encoder.encode(bytes, startIndex: 0, length: bytes.count, output: &output)) ?? 0
        let encodedText = String(bytes: output.prefix(written), encoding: .ascii) ?? ""
        let charset = CharsetUtils.getMimeCharset(chosenEncoding)

        builder.append("=?")
        builder.append(charset)
        builder.append("?")
        builder.append(String(encoder.encoding))
        builder.append("?")
        builder.append(encodedText)
        builder.append("?=")

        return builder.length - startLength
    }

    private static func appendQuoted(builder: inout ValueStringBuilder, text: String, startIndex: Int, length: Int) {
        let value = substring(text, startIndex: startIndex, length: length)
        builder.append("\"")
        for ch in value {
            if ch == "\"" || ch == "\\" {
                builder.append("\\")
            }
            builder.append(ch)
        }
        builder.append("\"")
    }

    private static func getRfc822Words(
        _ options: FormatOptions,
        _ charset: String.Encoding,
        _ text: String,
        startIndex: Int,
        count: Int,
        phrase: Bool
    ) -> [Word] {
        let units = Array(text.utf16)
        let endIndex = startIndex + count
        var words: [Word] = []

        let saved = Word(startIndex)
        var word = Word(startIndex)
        var commentDepth = 0
        var escaped = false
        var quoted = false
        var i = startIndex

        while i < endIndex {
            let c = units[i]
            i += 1

            if !quoted && commentDepth == 0 && isBlank(c) {
                if word.byteCount > 0 {
                    words.append(word)
                    word = Word(i)
                } else {
                    word.startIndex = i
                }
                continue
            }

            word.copy(to: saved)
            var nchars = 1

            if c < 127 {
                if isCtrl(c) {
                    word.encoding = maxEncoding(word.encoding, .latin1)
                    word.type = .encodedWord
                    word.encodeCount += 1
                } else if phrase && !isAtom(c) {
                    if word.type == .atom {
                        word.type = .quotedString
                    }

                    if c == 0x5C { // '\\'
                        word.quotedPairs += 1
                        escaped.toggle()
                    } else if c == 0x22 { // '"'
                        if !escaped {
                            quoted.toggle()
                            if quoted {
                                word.isQuotedStart = true
                            } else {
                                word.isQuotedEnd = true
                            }
                        }
                        word.quotedPairs += 1
                        escaped = false
                    } else if !quoted {
                        if c == 0x28 { // '('
                            word.isCommentStart = commentDepth == 0
                            commentDepth += 1
                        } else if c == 0x29 && commentDepth > 0 { // ')'
                            commentDepth -= 1
                            word.isCommentEnd = commentDepth == 0
                        }
                    } else {
                        escaped = false
                    }
                }

                word.byteCount += 1
                word.charCount += 1
                nchars = 1
            } else if c < 256 {
                word.encoding = maxEncoding(word.encoding, .latin1)
                word.type = .encodedWord
                word.encodeCount += 1
                word.byteCount += 1
                word.charCount += 1
                nchars = 1
            } else {
                if isHighSurrogate(c) && i < endIndex && isLowSurrogate(units[i]) {
                    i += 1
                    nchars = 2
                } else {
                    nchars = 1
                }

                let substring = stringFromUtf16(units, startIndex: i - nchars, length: nchars)
                let bytes = substring.data(using: charset)?.count ?? (3 * nchars)
                word.encoding = .userSpecified
                word.type = .encodedWord
                word.charCount += nchars
                word.encodeCount += bytes
                word.byteCount += bytes
            }

            if exceedsMaxLineLength(options, charset, word) {
                saved.copy(to: word)
                i -= nchars

                if word.type == .atom {
                    word.type = .encodedWord
                    let n = "us-ascii".count + 7
                    word.charCount -= n
                    word.byteCount -= n
                    i -= n
                }

                words.append(word)
                saved.type = word.type
                word = Word(i)
                word.type = saved.type
            } else if word.isQuotedEnd || word.isCommentEnd {
                if word.type == .encodedWord {
                    if word.isQuotedEnd && !word.isQuotedStart {
                        for index in stride(from: words.count - 1, through: 0, by: -1) {
                            words[index].type = .encodedWord
                            if words[index].isQuotedStart {
                                break
                            }
                        }
                    } else if word.isCommentEnd && !word.isCommentStart {
                        for index in stride(from: words.count - 1, through: 0, by: -1) {
                            words[index].type = .encodedWord
                            if words[index].isCommentStart {
                                break
                            }
                        }
                    }
                }

                words.append(word)
                word = Word(i)
            }
        }

        if word.byteCount > 0 {
            words.append(word)
        }

        return words
    }

    private static func shouldMergeWords(
        _ options: FormatOptions,
        _ charset: String.Encoding,
        _ words: [Word],
        _ word: Word,
        _ index: Int
    ) -> Bool {
        let next = words[index]
        let lwspCount = next.startIndex - (word.startIndex + word.charCount)
        var length = word.byteCount + lwspCount + next.byteCount
        let encoded = word.encodeCount + next.encodeCount

        switch word.type {
        case .atom:
            if next.type == .encodedWord {
                return false
            }
            return length + 1 < options.maxLineLength
        case .quotedString:
            if next.type == .encodedWord {
                return false
            }
            return true
        case .encodedWord:
            if next.type == .atom {
                var merge = false
                var natoms = 0
                var j = index + 1
                while j < words.count && natoms < 3 {
                    if words[j].type != .atom {
                        merge = true
                        break
                    }
                    natoms += 1
                    j += 1
                }
                if !merge {
                    return false
                }
            }
            if next.type == .quotedString {
                return false
            }

            let encoding = maxEncoding(word.encoding, next.encoding)
            switch encoding {
            case .latin1:
                length = estimateEncodedWordLength("iso-8859-1", byteCount: length, encodeCount: encoded)
            case .ascii:
                length = estimateEncodedWordLength("us-ascii", byteCount: length, encodeCount: encoded)
            case .userSpecified:
                length = estimateEncodedWordLength(charset, byteCount: length, encodeCount: encoded)
            }
            return length + 1 < options.maxLineLength
        }
    }

    private static func mergeWords(_ word: Word, _ next: Word) {
        let lwspCount = next.startIndex - (word.startIndex + word.charCount)
        word.type = maxWordType(word.type, next.type)
        word.charCount = (next.startIndex + next.charCount) - word.startIndex
        word.byteCount = word.byteCount + lwspCount + next.byteCount
        word.encoding = maxEncoding(word.encoding, next.encoding)
        word.encodeCount += next.encodeCount
        word.quotedPairs += next.quotedPairs
    }

    private static func mergeAdjacent(_ options: FormatOptions, _ charset: String.Encoding, _ words: [Word]) -> [Word] {
        guard let first = words.first else { return words }
        var merged: [Word] = [first]
        var current = first

        for next in words.dropFirst() {
            if current.type != .atom && current.type == next.type {
                let encoding = maxEncoding(current.encoding, next.encoding)
                let lwspCount = next.startIndex - (current.startIndex + current.charCount)
                let byteCount = current.byteCount + lwspCount + next.byteCount
                let encoded = current.encodeCount + next.encodeCount
                let quoted = current.quotedPairs + next.quotedPairs
                let length: Int

                if current.type == .encodedWord {
                    switch encoding {
                    case .latin1:
                        length = estimateEncodedWordLength("iso-8859-1", byteCount: byteCount, encodeCount: encoded)
                    case .ascii:
                        length = estimateEncodedWordLength("us-ascii", byteCount: byteCount, encodeCount: encoded)
                    case .userSpecified:
                        length = estimateEncodedWordLength(charset, byteCount: byteCount, encodeCount: encoded)
                    }
                } else {
                    length = byteCount + quoted + 2
                }

                if length + 1 < options.maxLineLength {
                    current.charCount = (next.startIndex + next.charCount) - current.startIndex
                    current.byteCount = byteCount
                    current.encodeCount = encoded
                    current.quotedPairs = quoted
                    current.encoding = encoding
                    continue
                }
            }

            merged.append(next)
            current = next
        }

        return merged
    }

    private static func merge(_ options: FormatOptions, _ charset: String.Encoding, _ words: [Word]) -> [Word] {
        guard words.count > 1 else { return words }
        let firstPass = mergeAdjacent(options, charset, words)
        var merged: [Word] = []
        guard let first = firstPass.first else { return merged }
        merged.append(first)
        var current = first

        for index in 1..<firstPass.count {
            let next = firstPass[index]
            if shouldMergeWords(options, charset, firstPass, current, index) {
                mergeWords(current, next)
            } else {
                merged.append(next)
                current = next
            }
        }

        return merged
    }

    private static func encodeInternal(
        _ builder: inout ValueStringBuilder,
        _ options: FormatOptions,
        _ charset: String.Encoding,
        _ text: String,
        startIndex: Int,
        count: Int,
        type: EncodeType
    ) {
        let mode: QEncodeMode = (type == .phrase) ? .phrase : .text
        var words = getRfc822Words(options, charset, text, startIndex: startIndex, count: count, phrase: type == .phrase)
        var previous: Word? = nil

        words = merge(options, charset, words)

        if !options.allowMixedHeaderCharsets {
            for word in words where word.type == .encodedWord {
                word.encoding = .userSpecified
            }
        }

        if type == .comment {
            builder.append("(")
        }

        for word in words {
            if let previous, !(previous.type == .encodedWord && word.type == .encodedWord) {
                let start = previous.startIndex + previous.charCount
                let length = word.startIndex - start
                if length > 0 {
                    builder.append(substring(text, startIndex: start, length: length))
                }
            }

            switch word.type {
            case .atom:
                builder.append(substring(text, startIndex: word.startIndex, length: word.charCount))
            case .quotedString:
                appendQuoted(builder: &builder, text: text, startIndex: word.startIndex, length: word.charCount)
            case .encodedWord:
                var start = word.startIndex
                var length = word.charCount

                if let previous, previous.type == .encodedWord {
                    start = previous.startIndex + previous.charCount
                    length = (word.startIndex + word.charCount) - start
                    builder.append(type == .phrase ? "\t" : " ")
                }

                switch word.encoding {
                case .ascii:
                    _ = appendEncodedWord(builder: &builder, encoding: .ascii, text: text, startIndex: start, length: length, mode: mode)
                case .latin1:
                    _ = appendEncodedWord(builder: &builder, encoding: .isoLatin1, text: text, startIndex: start, length: length, mode: mode)
                case .userSpecified:
                    _ = appendEncodedWord(builder: &builder, encoding: charset, text: text, startIndex: start, length: length, mode: mode)
                }
            }

            previous = word
        }

        if type == .comment {
            builder.append(")")
        }
    }

    private static func encodeAsBytes(
        _ options: FormatOptions,
        _ charset: String.Encoding,
        _ text: String,
        startIndex: Int,
        count: Int,
        type: EncodeType
    ) -> [UInt8] {
        var builder = ValueStringBuilder(initialCapacity: max(0, count * 4))
        encodeInternal(&builder, options, charset, text, startIndex: startIndex, count: count, type: type)
        return Array(builder.asString().utf8)
    }

    private static func encodeAsString(
        _ options: FormatOptions,
        _ charset: String.Encoding,
        _ text: String,
        startIndex: Int,
        count: Int,
        type: EncodeType
    ) -> String {
        var builder = ValueStringBuilder(initialCapacity: max(0, count * 4))
        encodeInternal(&builder, options, charset, text, startIndex: startIndex, count: count, type: type)
        return builder.asString()
    }

    private struct Token {
        let charsetCulture: String?
        let startIndex: Int
        let length: Int
        let encoding: Character
        let codepage: Int

        var is8bit: Bool { codepage == 0 && encoding == "8" }
        var isEncoded: Bool { codepage != 0 }

        init(charset: String, culture: String?, encoding: Character, startIndex: Int, length: Int) {
            if let culture, !culture.isEmpty {
                charsetCulture = "\(charset)*\(culture)"
            } else {
                charsetCulture = charset
            }
            codepage = CharsetUtils.getCodePage(charset)
            self.encoding = encoding
            self.startIndex = startIndex
            self.length = length
        }

        init(startIndex: Int, length: Int, is8bit: Bool = false) {
            encoding = is8bit ? "8" : "7"
            charsetCulture = nil
            codepage = 0
            self.startIndex = startIndex
            self.length = length
        }
    }

    private protocol TokenWriter: AnyObject {
        var ignoreWhitespaceBetweenEncodedWords: Bool { get }
        func write(_ output: inout ValueStringBuilder, token: Token)
        func flush(_ output: inout ValueStringBuilder)
    }

    private final class TokenFolder: TokenWriter {
        private let options: FormatOptions
        private let input: [UInt8]
        private var firstToken = true
        private var lineLength: Int
        private var lwsp = 0
        private var tab = 0

        init(options: FormatOptions, field: String, input: [UInt8]) {
            self.options = options
            self.input = input
            self.lineLength = field.count + 1
        }

        var ignoreWhitespaceBetweenEncodedWords: Bool { false }

        func write(_ output: inout ValueStringBuilder, token: Token) {
            guard token.length > 0 else { return }
            if firstToken {
                output.append(" ")
                lineLength += 1
            } else if lineLength == 0 {
                output.append(" ")
                lineLength = 1
            }

            if ByteClassification.isWhitespace(input[token.startIndex]) {
                for index in token.startIndex..<(token.startIndex + token.length) {
                    let byte = input[index]
                    if byte == 0x0D {
                        continue
                    }
                    lwsp = output.length
                    if byte == 0x09 {
                        tab = output.length
                    }
                    if byte == 0x0A {
                        output.append(options.newLine)
                        lwsp = 0
                        tab = 0
                        lineLength = 0
                    } else {
                        output.append(Character(UnicodeScalar(UInt32(byte))!))
                        lineLength += 1
                    }
                }
                firstToken = false
                return
            }

            if token.isEncoded {
                let charset = token.charsetCulture ?? ""
                if lineLength + token.length + charset.count + 7 > options.maxLineLength {
                    if tab != 0 {
                        output.insert(options.newLine, at: tab)
                        lineLength = (lwsp - tab) + 1
                    } else if lwsp != 0 {
                        output.insert(options.newLine, at: lwsp)
                        lineLength = 1
                    } else if lineLength > 1 && !firstToken {
                        output.append(options.newLine)
                        output.append(" ")
                        lineLength = 1
                    }
                }

                output.append("=?")
                output.append(charset)
                output.append("?")
                output.append(String(token.encoding))
                output.append("?")
                for index in token.startIndex..<(token.startIndex + token.length) {
                    output.append(Character(UnicodeScalar(UInt32(input[index]))!))
                }
                output.append("?=")

                lineLength += token.length + charset.count + 7
                firstToken = false
                lwsp = 0
                tab = 0
                return
            }

            if lineLength + token.length > options.maxLineLength {
                if tab != 0 {
                    output.insert(options.newLine, at: tab)
                    lineLength = (lwsp - tab) + 1
                } else if lwsp != 0 {
                    output.insert(options.newLine, at: lwsp)
                    lineLength = 1
                } else if lineLength > 1 && !firstToken {
                    output.append(options.newLine)
                    output.append(" ")
                    lineLength = 1
                }

                if token.length >= options.maxLineLength {
                    for index in token.startIndex..<(token.startIndex + token.length) {
                        if lineLength >= options.maxLineLength {
                            output.append(options.newLine)
                            output.append(" ")
                            lineLength = 1
                        }
                        output.append(Character(UnicodeScalar(UInt32(input[index]))!))
                        lineLength += 1
                    }
                } else {
                    for index in token.startIndex..<(token.startIndex + token.length) {
                        output.append(Character(UnicodeScalar(UInt32(input[index]))!))
                    }
                    lineLength += token.length
                }

                firstToken = false
                lwsp = 0
                tab = 0
                return
            }

            for index in token.startIndex..<(token.startIndex + token.length) {
                output.append(Character(UnicodeScalar(UInt32(input[index]))!))
            }
            lineLength += token.length
            firstToken = false
            lwsp = 0
            tab = 0
        }

        func flush(_ output: inout ValueStringBuilder) {
            if output.length == 0 || output[output.length - 1] != "\n" {
                output.append(options.newLine)
            }
        }
    }

    private static func isAscii(_ byte: UInt8) -> Bool {
        byte < 128
    }

    private static func isAsciiAtom(_ byte: UInt8) -> Bool {
        ByteClassification.isAsciiAtom(byte)
    }

    private static func isBbQq(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "B") || byte == UInt8(ascii: "b") || byte == UInt8(ascii: "Q") || byte == UInt8(ascii: "q")
    }

    private static func isLwsp(_ byte: UInt8) -> Bool {
        ByteClassification.isWhitespace(byte)
    }

    private static func tryGetEncodedWordToken(_ input: [UInt8], startIndex: Int, length: Int) -> Token? {
        guard length >= 7 else { return nil }
        let endIndex = startIndex + length
        guard input[startIndex] == UInt8(ascii: "="),
              input[startIndex + 1] == UInt8(ascii: "?"),
              input[endIndex - 2] == UInt8(ascii: "?"),
              input[endIndex - 1] == UInt8(ascii: "=") else {
            return nil
        }

        var index = startIndex + 2
        if input[index] == UInt8(ascii: "?") || input[index] == UInt8(ascii: "*") {
            return nil
        }

        var charsetBytes: [UInt8] = []
        while index < endIndex && input[index] != UInt8(ascii: "?") && input[index] != UInt8(ascii: "*") {
            let byte = input[index]
            if !isAsciiAtom(byte) {
                return nil
            }
            charsetBytes.append(byte)
            index += 1
        }
        guard !charsetBytes.isEmpty else { return nil }
        guard let charset = String(bytes: charsetBytes, encoding: .ascii) else { return nil }

        var culture: String? = nil
        if index < endIndex && input[index] == UInt8(ascii: "*") {
            index += 1
            var cultureBytes: [UInt8] = []
            while index < endIndex && input[index] != UInt8(ascii: "?") {
                let byte = input[index]
                if !isAsciiAtom(byte) {
                    return nil
                }
                cultureBytes.append(byte)
                index += 1
            }
            guard !cultureBytes.isEmpty else { return nil }
            culture = String(bytes: cultureBytes, encoding: .ascii)
        }

        guard index < endIndex && input[index] == UInt8(ascii: "?") else { return nil }
        index += 1
        guard index < endIndex else { return nil }
        let encodingByte = input[index]
        guard isBbQq(encodingByte) else { return nil }
        index += 1
        guard index < endIndex && input[index] == UInt8(ascii: "?") else { return nil }
        index += 1
        guard index < endIndex - 2 else { return nil }

        let payloadStart = index
        let payloadLength = (endIndex - 2) - payloadStart
        guard payloadLength > 0 else { return nil }

        return Token(charset: charset, culture: culture, encoding: Character(UnicodeScalar(UInt32(encodingByte))!), startIndex: payloadStart, length: payloadLength)
    }

    private static func tokenizeText(
        _ options: ParserOptions,
        _ writer: TokenWriter,
        _ output: inout ValueStringBuilder,
        _ input: [UInt8],
        startIndex: Int,
        length: Int
    ) {
        var inptr = startIndex
        let endIndex = startIndex + length
        var encoded = false
        var lwsp = Token(startIndex: 0, length: 0)

        while inptr < endIndex {
            let textStart = inptr
            while inptr < endIndex && isLwsp(input[inptr]) {
                inptr += 1
            }
            lwsp = Token(startIndex: textStart, length: inptr - textStart)

            if inptr < endIndex {
                let wordStart = inptr
                var ascii = true

                if options.rfc2047ComplianceMode == .loose {
                    var isRfc2047 = false
                    if inptr + 2 < endIndex && input[inptr] == UInt8(ascii: "=") && input[inptr + 1] == UInt8(ascii: "?") {
                        inptr += 2
                        while inptr < endIndex && input[inptr] != UInt8(ascii: "?") {
                            ascii = ascii && isAscii(input[inptr])
                            inptr += 1
                        }

                        if inptr + 3 >= endIndex || input[inptr] != UInt8(ascii: "?") || !isBbQq(input[inptr + 1]) || input[inptr + 2] != UInt8(ascii: "?") {
                            ascii = true
                        } else {
                            inptr += 3
                            while inptr + 2 < endIndex && !(input[inptr] == UInt8(ascii: "?") && input[inptr + 1] == UInt8(ascii: "=")) {
                                ascii = ascii && isAscii(input[inptr])
                                inptr += 1
                            }
                            if inptr + 2 <= endIndex && input[inptr] == UInt8(ascii: "?") && input[inptr + 1] == UInt8(ascii: "=") {
                                isRfc2047 = true
                                inptr += 2
                            } else {
                                inptr = wordStart + 2
                                ascii = true
                            }
                        }
                    }

                    if !isRfc2047 {
                        while inptr < endIndex && !isLwsp(input[inptr]) {
                            if inptr + 2 < endIndex && input[inptr] == UInt8(ascii: "=") && input[inptr + 1] == UInt8(ascii: "?") {
                                break
                            }
                            ascii = ascii && isAscii(input[inptr])
                            inptr += 1
                        }
                    }
                } else {
                    while inptr < endIndex && !isLwsp(input[inptr]) {
                        ascii = ascii && isAscii(input[inptr])
                        inptr += 1
                    }
                }

                let length = inptr - wordStart
                if let token = tryGetEncodedWordToken(input, startIndex: wordStart, length: length) {
                    if (!encoded || !writer.ignoreWhitespaceBetweenEncodedWords) && lwsp.length > 0 {
                        writer.write(&output, token: lwsp)
                    }
                    writer.write(&output, token: token)
                    encoded = true
                } else {
                    if lwsp.length > 0 {
                        writer.write(&output, token: lwsp)
                    }
                    let token = Token(startIndex: wordStart, length: length, is8bit: !ascii)
                    writer.write(&output, token: token)
                    encoded = false
                }
            } else {
                if lwsp.length > 0 {
                    writer.write(&output, token: lwsp)
                }
                break
            }
        }

        writer.flush(&output)
    }

    private static func renderSegment(_ segment: String, needsEncoding: Bool, encoding: String.Encoding, mode: QEncodeMode) -> String {
        guard !segment.isEmpty else {
            return ""
        }
        if !needsEncoding {
            return segment
        }

        let bytes = CharsetUtils.getBytes(segment, encoding: encoding)
        let qpEncoder = Rfc2047QuotedPrintableEncoder(mode: mode)
        let base64Encoder = Rfc2047Base64Encoder()
        let qpLength = qpEncoder.estimateOutputLength(bytes.count)
        let bLength = base64Encoder.estimateOutputLength(bytes.count)
        let encoder: any Rfc2047Encoder = (bLength < qpLength) ? base64Encoder : qpEncoder

        let outputLength = encoder.estimateOutputLength(bytes.count)
        var output = Array(repeating: UInt8(0), count: outputLength)
        let written: Int
        do {
            written = try encoder.encode(bytes, startIndex: 0, length: bytes.count, output: &output)
        } catch {
            return segment
        }

        let encodedText = String(bytes: Array(output[0..<written]), encoding: .ascii) ?? segment
        let charset = CharsetUtils.getMimeCharset(encoding)
        let encodingLetter = String(encoder.encoding)
        return "=?\(charset)?\(encodingLetter)?\(encodedText)?="
    }

    private static func containsNonAsciiOrControl(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value > 127 || scalar.value < 32 || scalar.value == 127 {
                return true
            }
        }
        return false
    }

    private static func needsEncodingWord(_ word: String, options: FormatOptions) -> Bool {
        if containsNonAsciiOrControl(word) {
            return true
        }
        return word.count > options.maxLineLength
    }

    private static func needsPhraseSpecials(_ word: String) -> Bool {
        for ch in word {
            if isPhraseSpecial(ch) {
                return true
            }
        }
        return false
    }

    private static func canEncode(_ text: String, encoding: String.Encoding) -> Bool {
        text.data(using: encoding) != nil
    }

    private static func selectEncoding(_ options: FormatOptions, userEncoding: String.Encoding, text: String) -> String.Encoding {
        if options.allowMixedHeaderCharsets {
            if canEncode(text, encoding: .ascii) {
                return .ascii
            }
            if canEncode(text, encoding: .isoLatin1) {
                return .isoLatin1
            }
        }
        if canEncode(text, encoding: userEncoding) {
            return userEncoding
        }
        return .utf8
    }

    private enum EncodedWordEncoding {
        case base64
        case quotedPrintable
    }

    private static func chooseEncodedWordEncoding(_ bytes: [UInt8], encoding: String.Encoding, mode: QEncodeMode) -> EncodedWordEncoding {
        if charsetRequiresBase64(encoding) {
            return .base64
        }
        var nonAscii = 0
        for byte in bytes where byte > 127 {
            nonAscii += 1
        }
        if Double(nonAscii) < Double(bytes.count) * 0.17 {
            return .quotedPrintable
        }
        return .base64
    }

    private static func charsetRequiresBase64(_ encoding: String.Encoding) -> Bool {
        let codepage = CharsetUtils.getCodepage(encoding)
        return codepage == 50220 || codepage == 50222
    }

    private static func encodeRun(_ options: FormatOptions, userEncoding: String.Encoding, text: String, mode: QEncodeMode) -> String {
        let encoding = selectEncoding(options, userEncoding: userEncoding, text: text)
        guard let data = text.data(using: encoding) ?? text.data(using: .utf8) else {
            return text
        }
        let bytes = Array(data)
        let encodingChoice = chooseEncodedWordEncoding(bytes, encoding: encoding, mode: mode)

        let encoder: any Rfc2047Encoder = (encodingChoice == .base64) ? Rfc2047Base64Encoder() : Rfc2047QuotedPrintableEncoder(mode: mode)
        let charset = CharsetUtils.getMimeCharset(encoding)
        let encodingLetter = String(encoder.encoding)
        let maxPayload = max(4, options.maxLineLength - (charset.count + 7))

        let segments: [String]
        switch encodingChoice {
        case .base64:
            segments = encodeBase64Segments(text, encoding: encoding, maxPayload: maxPayload)
        case .quotedPrintable:
            let qpPayload = max(4, maxPayload - 2)
            let outputLength = encoder.estimateOutputLength(bytes.count)
            var output = Array(repeating: UInt8(0), count: outputLength)
            let written: Int
            do {
                written = try encoder.encode(bytes, startIndex: 0, length: bytes.count, output: &output)
            } catch {
                return text
            }
            let encodedBytes = Array(output.prefix(written))
            segments = splitQuotedPrintableSegments(encodedBytes, maxPayload: qpPayload)
        }

        let encodedWords = segments.map { segment in
            "=?\(charset)?\(encodingLetter)?\(segment)?="
        }

        if encodedWords.count == 1 {
            return encodedWords[0]
        }
        return encodedWords.joined(separator: options.newLine + " ")
    }

    private static func splitCommentBase64Segments(options: FormatOptions, encoding: String.Encoding, text: String) -> [String] {
        let maxEncodedWordLength = max(1, options.maxLineLength - 2)
        let charset = CharsetUtils.getMimeCharset(encoding)
        let maxPayload = max(4, maxEncodedWordLength - (charset.count + 7))
        let maxBytes = max(1, (maxPayload / 4) * 3)
        var segments: [String] = []

        var words: [(leadingWhitespaceStart: String.Index, wordStart: String.Index, wordEnd: String.Index)] = []
        var index = text.startIndex
        while index < text.endIndex {
            let whitespaceStart = index
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }
            if index >= text.endIndex {
                break
            }
            let wordStart = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }
            let wordEnd = index
            words.append((leadingWhitespaceStart: whitespaceStart, wordStart: wordStart, wordEnd: wordEnd))
        }

        guard let first = words.first else {
            return [text]
        }

        var segmentStart = first.wordStart
        var segmentEnd = first.wordEnd

        func byteCount(_ range: Range<String.Index>) -> Int {
            let substring = String(text[range])
            return substring.lengthOfBytes(using: encoding)
        }

        for word in words.dropFirst() {
            let candidateRange = segmentStart..<word.wordEnd
            let candidateBytes = byteCount(candidateRange)
            if candidateBytes <= maxBytes || segmentStart == word.wordStart {
                segmentEnd = word.wordEnd
            } else {
                segments.append(String(text[segmentStart..<segmentEnd]))
                segmentStart = word.leadingWhitespaceStart
                segmentEnd = word.wordEnd
            }
        }

        segments.append(String(text[segmentStart..<segmentEnd]))
        return segments
    }

    private static func encodeBase64Segments(_ text: String, encoding: String.Encoding, maxPayload: Int) -> [String] {
        let encoder = Rfc2047Base64Encoder()
        let maxBytes = max(1, (maxPayload / 4) * 3)
        var segments: [String] = []
        var current = ""
        var currentBytes = 0

        func flush() {
            guard !current.isEmpty, let data = current.data(using: encoding) else { return }
            let bytes = Array(data)
            let outputLength = encoder.estimateOutputLength(bytes.count)
            var output = Array(repeating: UInt8(0), count: outputLength)
            let written = (try? encoder.encode(bytes, startIndex: 0, length: bytes.count, output: &output)) ?? 0
            let encoded = String(bytes: output.prefix(written), encoding: .ascii) ?? ""
            segments.append(encoded)
            current = ""
            currentBytes = 0
        }

        let characters = Array(text)
        for (idx, ch) in characters.enumerated() {
            let chStr = String(ch)
            let byteCount = chStr.lengthOfBytes(using: encoding)
            let hasMore = idx < (characters.count - 1)

            if !current.isEmpty {
                if currentBytes + byteCount > maxBytes {
                    flush()
                } else if ch.isWhitespace && hasMore && (currentBytes + byteCount) == maxBytes {
                    // Prefer starting a new encoded word at whitespace boundaries.
                    flush()
                }
            }

            current.append(chStr)
            currentBytes += byteCount
        }

        flush()

        return segments.isEmpty ? [""] : segments
    }

    private static func splitQuotedPrintableSegments(_ bytes: [UInt8], maxPayload: Int) -> [String] {
        guard !bytes.isEmpty else { return [""] }
        var segments: [String] = []
        var index = 0
        let limit = max(4, maxPayload)

        while index < bytes.count {
            var end = min(index + limit, bytes.count)
            if end < bytes.count {
                if bytes[end - 1] == 0x3D { // '='
                    end -= 1
                } else if end - 2 >= index && bytes[end - 2] == 0x3D {
                    end -= 2
                }
                if end <= index {
                    end = min(index + limit, bytes.count)
                }
            }
            let chunk = bytes[index..<end]
            segments.append(String(bytes: chunk, encoding: .ascii) ?? "")
            index = end
        }

        return segments
    }

    private static func needsQuotedPhrase(_ phrase: String) -> Bool {
        for ch in phrase {
            if isPhraseSpecial(ch) {
                return true
            }
        }
        return false
    }

    private static func isPhraseSpecial(_ ch: Character) -> Bool {
        let specials = "()<>@,;:\\\".[]"
        return specials.contains(ch)
    }
}
