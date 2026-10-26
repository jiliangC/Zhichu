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
// CharsetUtils.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during character set encoding and decoding operations.
public enum CharsetError: Error, Equatable, Sendable {
    /// The byte sequence is not valid for the specified encoding.
    case invalidSequence

    /// The requested character encoding is not supported on this platform.
    case unsupportedEncoding

    /// An argument provided to a charset operation was invalid.
    case invalidArgument
}

/// Utility methods for working with character set encodings.
///
/// `CharsetUtils` provides methods for converting between strings and byte arrays
/// using various character encodings, looking up encodings by charset name or code page,
/// and converting charset names to their canonical MIME forms.
///
/// ## Common Encodings
///
/// The type provides convenient constants for commonly used encodings:
///
/// ```swift
/// let utf8Bytes = CharsetUtils.getBytes("Hello", encoding: CharsetUtils.utf8)
/// let latin1Bytes = CharsetUtils.getBytes("Hello", encoding: CharsetUtils.latin1)
/// ```
///
/// ## Charset Lookup
///
/// Look up encodings by their IANA charset name or Windows code page:
///
/// ```swift
/// if let encoding = CharsetUtils.getEncoding("iso-8859-1") {
///     // Use the encoding
/// }
///
/// if let encoding = CharsetUtils.getEncoding(codepage: 65001) {
///     // UTF-8 encoding
/// }
/// ```
///
/// ## MIME Charset Names
///
/// Get the canonical MIME charset name for an encoding:
///
/// ```swift
/// let mimeCharset = CharsetUtils.getMimeCharset(.utf8)
/// // Returns: "utf-8"
/// ```
public enum CharsetUtils {
    /// The UTF-8 encoding.
    ///
    /// UTF-8 is the most commonly used encoding for MIME messages and can represent
    /// any Unicode character.
    public static let utf8: String.Encoding = .utf8

    /// The ISO-8859-1 (Latin-1) encoding.
    ///
    /// Latin-1 is a single-byte encoding that covers Western European languages.
    /// It is often used as a fallback when UTF-8 decoding fails.
    public static let latin1: String.Encoding = .isoLatin1

    /// The US-ASCII encoding.
    ///
    /// ASCII is a 7-bit encoding limited to basic English characters. It is the
    /// baseline encoding for MIME headers and is always safe to use.
    public static let ascii: String.Encoding = .ascii

    /// Converts a string to a byte array using the specified encoding.
    ///
    /// - Parameters:
    ///   - string: The string to convert.
    ///   - encoding: The character encoding to use. Defaults to UTF-8.
    /// - Returns: A byte array containing the encoded string, or an empty array
    ///   if the string cannot be represented in the specified encoding.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bytes = CharsetUtils.getBytes("Hello, World!", encoding: .utf8)
    /// ```
    public static func getBytes(_ string: String, encoding: String.Encoding = .utf8) -> [UInt8] {
        Array(string.data(using: encoding) ?? Data())
    }

    /// Attempts to convert a byte array to a string using the specified encoding.
    ///
    /// - Parameters:
    ///   - bytes: The byte array to convert.
    ///   - start: The starting index in the byte array.
    ///   - length: The number of bytes to convert.
    ///   - encoding: The character encoding to use. Defaults to UTF-8.
    /// - Returns: The decoded string, or `nil` if the bytes cannot be decoded
    ///   using the specified encoding or if the range is invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bytes: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello" in ASCII
    /// if let text = CharsetUtils.tryGetString(bytes, start: 0, length: bytes.count) {
    ///     print(text)  // "Hello"
    /// }
    /// ```
    public static func tryGetString(_ bytes: [UInt8], start: Int, length: Int, encoding: String.Encoding = .utf8) -> String? {
        let end = start + length
        guard start >= 0, length >= 0, end <= bytes.count else { return nil }
        let data = Data(bytes[start..<end])
        return String(data: data, encoding: encoding)
    }

    /// Converts a byte array to a string using the specified encoding.
    ///
    /// - Parameters:
    ///   - bytes: The byte array to convert.
    ///   - start: The starting index in the byte array.
    ///   - length: The number of bytes to convert.
    ///   - encoding: The character encoding to use. Defaults to UTF-8.
    /// - Returns: The decoded string.
    /// - Throws: ``CharsetError/invalidSequence`` if the bytes cannot be decoded
    ///   using the specified encoding.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bytes: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello" in ASCII
    /// let text = try CharsetUtils.getString(bytes, start: 0, length: bytes.count)
    /// print(text)  // "Hello"
    /// ```
    public static func getString(_ bytes: [UInt8], start: Int, length: Int, encoding: String.Encoding = .utf8) throws -> String {
        if let value = tryGetString(bytes, start: start, length: length, encoding: encoding) {
            return value
        }
        throw CharsetError.invalidSequence
    }

    /// Gets the encoding for the specified charset name.
    ///
    /// Looks up a character encoding by its IANA charset name. This method handles
    /// common charset aliases and variations in naming (e.g., "utf-8" and "utf8"
    /// both return UTF-8).
    ///
    /// - Parameter charset: The IANA charset name (case-insensitive).
    /// - Returns: The corresponding `String.Encoding`, or `nil` if the charset
    ///   is not recognized or not supported.
    ///
    /// ## Supported Charsets
    ///
    /// This method supports many common charsets including:
    /// - UTF-8, US-ASCII, ISO-8859-1 through ISO-8859-15
    /// - Windows code pages (windows-1252, etc.)
    /// - Asian encodings (Shift_JIS, EUC-JP, EUC-KR, GB2312, GB18030, Big5)
    /// - And many more through the platform's charset support
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let encoding = CharsetUtils.getEncoding("iso-8859-1") {
    ///     let text = String(data: data, encoding: encoding)
    /// }
    /// ```
    public static func getEncoding(_ charset: String) -> String.Encoding? {
        let normalized = charset.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty {
            return nil
        }

        switch normalized {
        case "utf8", "utf-8", "unicode-1-1-utf-8":
            return .utf8
        case "us-ascii", "ascii", "ansi_x3.4-1968":
            return .ascii
        case "iso-8859-1", "latin1", "iso-ir-100":
            return .isoLatin1
        case "big5", "big-5":
            return encodingFromCodepage(950)
        case "koi8-r", "koi8r":
            return encodingFromCodepage(20866)
        case "koi8-u", "koi8u":
            return encodingFromCodepage(21866)
        case "euc-cn", "euc_cn":
            return encodingFromCodepage(51936)
        case "euc-kr", "euc_kr", "euckr", "ks_c_5601-1987", "ks_c_5601-1989":
            return encodingFromCodepage(51949)
        case "gb2312", "gb2312-80", "gbk":
            return encodingFromCodepage(936)
        case "euc-jp", "euc_jp":
            return encodingFromCodepage(51932)
        case "shift_jis", "shift-jis", "sjis", "x-sjis", "windows-31j":
            return encodingFromCodepage(932)
        case "gb18030", "gb18030-0":
            return encodingFromCodepage(54936)
        default:
            let codepage = parseCodePage(normalized)
            if codepage > 0, let encoding = encodingFromCodepage(codepage) {
                return encoding
            }
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(normalized as CFString)
            if cfEncoding == kCFStringEncodingInvalidId {
                return nil
            }
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return String.Encoding(rawValue: nsEncoding)
        }
    }

    /// Gets the encoding for the specified Windows code page.
    ///
    /// - Parameter codepage: The Windows code page number.
    /// - Returns: The corresponding `String.Encoding`, or `nil` if the code page
    ///   is invalid or not supported.
    ///
    /// ## Common Code Pages
    ///
    /// - 65001: UTF-8
    /// - 20127: US-ASCII
    /// - 28591: ISO-8859-1 (Latin-1)
    /// - 1252: Windows-1252 (Western European)
    /// - 932: Shift_JIS
    /// - 936: GBK/GB2312
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let encoding = CharsetUtils.getEncoding(codepage: 65001) {
    ///     // UTF-8 encoding
    /// }
    /// ```
    public static func getEncoding(codepage: Int) -> String.Encoding? {
        if codepage <= 0 {
            return nil
        }
        return encodingFromCodepage(codepage)
    }

    /// Gets the encoding for the specified charset name, or a fallback if not found.
    ///
    /// - Parameters:
    ///   - charset: The IANA charset name (case-insensitive).
    ///   - fallback: The encoding to return if the charset is not recognized.
    /// - Returns: The corresponding `String.Encoding`, or `fallback` if the charset
    ///   is not recognized or not supported.
    public static func getEncodingOrDefault(_ charset: String, fallback: String.Encoding) -> String.Encoding {
        return getEncoding(charset) ?? fallback
    }

    /// Gets the encoding for the specified code page, or a fallback if not found.
    ///
    /// - Parameters:
    ///   - codepage: The Windows code page number.
    ///   - fallback: The encoding to return if the code page is not supported.
    /// - Returns: The corresponding `String.Encoding`, or `fallback` if the code page
    ///   is invalid or not supported.
    public static func getEncodingOrDefault(_ codepage: Int, fallback: String.Encoding) -> String.Encoding {
        if codepage == 0 {
            return fallback
        }

        let cfEncoding = CFStringConvertWindowsCodepageToEncoding(UInt32(codepage))
        if cfEncoding != kCFStringEncodingInvalidId {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return String.Encoding(rawValue: nsEncoding)
        }

        switch codepage {
        case 65001:
            return .utf8
        case 20127:
            return .ascii
        case 28591:
            return .isoLatin1
        default:
            return fallback
        }
    }

    /// Gets the canonical MIME charset name for an encoding.
    ///
    /// Returns the IANA charset name that should be used in MIME headers
    /// (such as Content-Type) for the specified encoding.
    ///
    /// - Parameter encoding: The encoding to get the MIME charset name for.
    /// - Returns: The canonical MIME charset name in lowercase.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let charset = CharsetUtils.getMimeCharset(.utf8)
    /// // Returns: "utf-8"
    ///
    /// let charset2 = CharsetUtils.getMimeCharset(.japaneseEUC)
    /// // Returns: "euc-jp"
    /// ```
    public static func getMimeCharset(_ encoding: String.Encoding) -> String {
        let codepage = getCodepage(encoding)
        switch codepage {
        case 932:
            return "shift_jis"
        case 949:
            return "euc-kr"
        case 50220, 50221, 50222:
            return "iso-2022-jp"
        case 50225:
            return "euc-kr"
        case 54936:
            return "gb18030"
        default:
            break
        }

        let cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
        if let name = CFStringConvertEncodingToIANACharSetName(cfEncoding) {
            return (name as String).lowercased()
        }
        switch encoding {
        case .utf8:
            return "utf-8"
        case .ascii:
            return "us-ascii"
        case .isoLatin1:
            return "iso-8859-1"
        default:
            return "utf-8"
        }
    }

    /// Gets the canonical MIME charset name for a charset string.
    ///
    /// Normalizes a charset name to its canonical MIME form. If the charset
    /// is recognized, returns the standard IANA name; otherwise, returns the
    /// input converted to lowercase.
    ///
    /// - Parameter charset: The charset name to normalize.
    /// - Returns: The canonical MIME charset name in lowercase.
    public static func getMimeCharset(_ charset: String) -> String {
        if let encoding = getEncoding(charset) {
            return getMimeCharset(encoding)
        }
        return charset.lowercased()
    }

    /// Gets the Windows code page number for an encoding.
    ///
    /// - Parameter encoding: The encoding to get the code page for.
    /// - Returns: The Windows code page number. Returns 65001 (UTF-8) if the
    ///   encoding's code page cannot be determined.
    ///
    /// ## Common Return Values
    ///
    /// - 65001: UTF-8
    /// - 20127: US-ASCII
    /// - 28591: ISO-8859-1
    public static func getCodepage(_ encoding: String.Encoding) -> Int {
        let cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
        let codepage = CFStringConvertEncodingToWindowsCodepage(cfEncoding)
        if codepage != kCFStringEncodingInvalidId && codepage != 0 {
            return Int(codepage)
        }

        switch encoding {
        case .utf8:
            return 65001
        case .ascii:
            return 20127
        case .isoLatin1:
            return 28591
        default:
            return 65001
        }
    }

    /// Gets the Windows code page number for a charset name.
    ///
    /// - Parameter charset: The IANA charset name.
    /// - Returns: The Windows code page number, or `-1` if the charset is not
    ///   recognized or not supported.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let codepage = CharsetUtils.getCodePage("utf-8")
    /// // Returns: 65001
    ///
    /// let unknown = CharsetUtils.getCodePage("unknown-charset")
    /// // Returns: -1
    /// ```
    public static func getCodePage(_ charset: String) -> Int {
        let trimmed = charset.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return -1
        }

        let normalized = trimmed.lowercased()
        if normalized.hasPrefix("iso-8859-") {
            let suffix = normalized.dropFirst("iso-8859-".count)
            if let variant = Int(suffix) {
                if variant == 11 {
                    return 874
                }
                if variant == 10 || variant == 12 || variant == 14 {
                    return -1
                }
            }
        }
        let parsed = parseCodePage(normalized)
        if parsed != -1 {
            return encodingFromCodepage(parsed) != nil ? parsed : -1
        }

        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(normalized as CFString)
        if cfEncoding == kCFStringEncodingInvalidId {
            return -1
        }

        let codepage = CFStringConvertEncodingToWindowsCodepage(cfEncoding)
        if codepage == kCFStringEncodingInvalidId || codepage == 0 {
            return -1
        }
        return Int(codepage)
    }

    /// Parses a code page number from a charset name.
    ///
    /// Attempts to extract a Windows code page number from charset names that
    /// include numeric identifiers, such as "windows-1252", "cp437", or "iso-8859-1".
    ///
    /// - Parameter charset: The charset name to parse.
    /// - Returns: The extracted code page number, or `-1` if the charset name
    ///   does not contain a parseable code page.
    ///
    /// ## Recognized Formats
    ///
    /// - `windows-XXXX` or `windows-cpXXXX`
    /// - `cpXXXX` or `cp-XXXX`
    /// - `iso-XXXX-X` (e.g., iso-8859-1)
    /// - `latin1` (returns 28591)
    public static func parseCodePage(_ charset: String) -> Int {
        let trimmed = charset.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return -1
        }

        var normalized = trimmed.lowercased()
        normalized = normalized.replacingOccurrences(of: "_", with: "-")

        if normalized == "latin1" {
            return 28591
        }

        if normalized.hasPrefix("windows") {
            var suffix = normalized.dropFirst("windows".count)
            if suffix.isEmpty {
                return -1
            }
            if suffix.hasPrefix("-cp") {
                suffix = suffix.dropFirst(3)
            } else if suffix.hasPrefix("-") {
                suffix = suffix.dropFirst(1)
            } else {
                return -1
            }
            guard let codepage = Int(suffix) else {
                return -1
            }
            return codepage
        }

        if normalized.hasPrefix("cp") {
            let suffix = normalized.dropFirst(2)
            if suffix.isEmpty {
                return -1
            }
            let digits = suffix.hasPrefix("-") ? suffix.dropFirst() : suffix
            guard let codepage = Int(digits) else {
                return -1
            }
            return codepage
        }

        if normalized.hasPrefix("iso") {
            var suffix = normalized.dropFirst(3)
            if suffix.hasPrefix("-") {
                suffix = suffix.dropFirst()
            }

            let components = suffix.split(separator: "-")
            guard let isoNumber = components.first, let isoValue = Int(isoNumber) else {
                return -1
            }

            if isoValue == 10646 {
                return 1201
            }

            if isoValue == 8859 {
                guard components.count == 2, let variant = Int(components[1]) else {
                    return -1
                }
                if variant == 11 {
                    return 874
                }
                if variant <= 0 || variant == 10 || variant == 12 || variant == 14 || variant > 15 {
                    return -1
                }
                return 28590 + variant
            }

            if isoValue == 2022 {
                guard components.count == 2 else {
                    return -1
                }
                switch components[1] {
                case "jp":
                    return 50220
                case "kr":
                    return 50225
                default:
                    return -1
                }
            }

            return -1
        }

        return -1
    }

    /// Converts a byte array to a Unicode string using best-effort decoding.
    ///
    /// Attempts to decode the bytes using multiple encodings in order of preference:
    /// UTF-8, the encoding specified in parser options, and finally ISO-8859-1
    /// as a fallback. This ensures that some text is always returned, even if
    /// the original encoding cannot be determined.
    ///
    /// - Parameters:
    ///   - options: Parser options containing the preferred charset encoding.
    ///   - bytes: The byte array to convert.
    ///   - start: The starting index in the byte array.
    ///   - length: The number of bytes to convert.
    /// - Returns: The decoded string. If all standard decodings fail, returns
    ///   the bytes interpreted as UTF-8 with replacement characters for
    ///   invalid sequences.
    public static func convertToUnicode(_ options: ParserOptions, _ bytes: [UInt8], start: Int, length: Int) -> String {
        if let value = tryGetString(bytes, start: start, length: length, encoding: .utf8) {
            return value
        }
        if let value = tryGetString(bytes, start: start, length: length, encoding: options.charsetEncoding) {
            return value
        }
        if let value = tryGetString(bytes, start: start, length: length, encoding: .isoLatin1) {
            return value
        }
        return String(decoding: bytes[start..<(start + length)], as: UTF8.self)
    }

    private static func encodingFromCodepage(_ codepage: Int) -> String.Encoding? {
        let cfEncoding = CFStringConvertWindowsCodepageToEncoding(UInt32(codepage))
        if cfEncoding == kCFStringEncodingInvalidId {
            return nil
        }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }
}
