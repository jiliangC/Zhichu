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
// MimeUtils.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during MIME utility operations.
enum MimeUtilsError: Error, Equatable {
    /// The argument provided was invalid.
    case invalidArgument
}

/// MIME utility methods.
///
/// `MimeUtils` provides various utility methods for working with MIME messages,
/// including quoting and unquoting strings, generating message identifiers,
/// and parsing MIME-related values such as Message-Id references and version strings.
///
/// ## Quoting and Unquoting
///
/// RFC 2822 and related specifications require certain values to be quoted when they
/// contain special characters. Use ``quote(_:)`` and ``unquote(_:convertTabsToSpaces:)``
/// to handle this:
///
/// ```swift
/// let quoted = MimeUtils.quote("Hello \"World\"")
/// // "\"Hello \\\"World\\\"\""
///
/// let original = MimeUtils.unquote(quoted)
/// // "Hello \"World\""
/// ```
///
/// ## Message-Id Generation
///
/// Generate unique identifiers for Message-Id and Content-Id headers:
///
/// ```swift
/// let messageId = MimeUtils.generateMessageId("example.com")
/// // e.g., "550e8400-e29b-41d4-a716-446655440000@example.com"
/// ```
///
/// ## Parsing References
///
/// Parse Message-Id references from headers like In-Reply-To and References:
///
/// ```swift
/// let references = MimeUtils.enumerateReferences("<abc@example.com> <def@example.com>")
/// // ["abc@example.com", "def@example.com"]
/// ```
enum MimeUtils {
    private static let unquoteChars: [Character] = ["\r", "\n", "\t", "\\", "\""]

    /// Quotes the specified text.
    ///
    /// Encloses the text in double-quotes and escapes any backslashes and
    /// double-quotes within the string by preceding them with a backslash.
    ///
    /// - Parameter text: The text to quote.
    /// - Returns: The quoted text enclosed in double-quotes with internal
    ///   special characters escaped.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let quoted = MimeUtils.quote("Hello \"World\"")
    /// // Returns: "\"Hello \\\"World\\\"\""
    /// ```
    static func quote(_ text: String) -> String {
        var builder = ValueStringBuilder(initialCapacity: (text.count * 2) + 2)
        builder.append("\"")
        for ch in text {
            if ch == "\\" || ch == "\"" {
                builder.append("\\")
            }
            builder.append(ch)
        }
        builder.append("\"")
        return builder.asString()
    }

    /// Unquotes the specified text.
    ///
    /// Removes surrounding double-quotes and unescapes any escaped characters
    /// (backslashes followed by another character). Also removes carriage returns
    /// and line feeds, which are sometimes inserted by mail clients during
    /// header folding.
    ///
    /// - Parameters:
    ///   - text: The text to unquote.
    ///   - convertTabsToSpaces: If `true`, tab characters are converted to spaces.
    ///     Defaults to `false`.
    /// - Returns: The unquoted text with escape sequences resolved.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let original = MimeUtils.unquote("\"Hello \\\"World\\\"\"")
    /// // Returns: "Hello \"World\""
    /// ```
    static func unquote(_ text: String, convertTabsToSpaces: Bool = false) -> String {
        guard text.firstIndex(where: { unquoteChars.contains($0) }) != nil else {
            return text
        }

        var builder = ValueStringBuilder(initialCapacity: text.count)
        var escaped = false
        var quoted = false

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0D, 0x0A:
                escaped = false
            case 0x09:
                builder.append(convertTabsToSpaces ? " " : "\t")
                escaped = false
            case 0x5C:
                if escaped {
                    builder.append("\\")
                }
                escaped.toggle()
            case 0x22:
                if escaped {
                    builder.append("\"")
                    escaped = false
                } else {
                    quoted.toggle()
                }
            default:
                builder.append(Character(scalar))
                escaped = false
            }
        }

        _ = quoted
        return builder.asString()
    }

    /// Unquotes the specified byte array.
    ///
    /// Removes surrounding double-quotes and unescapes any escaped characters
    /// from a raw byte buffer. Also removes carriage returns and line feeds.
    ///
    /// - Parameters:
    ///   - bytes: The raw byte buffer to unquote.
    ///   - startIndex: The index into the buffer to start processing.
    ///   - length: The number of bytes to process.
    ///   - convertTabsToSpaces: If `true`, tab characters (0x09) are converted
    ///     to spaces (0x20). Defaults to `false`.
    /// - Returns: A new byte array with the unquoted content.
    static func unquote(_ bytes: [UInt8], startIndex: Int, length: Int, convertTabsToSpaces: Bool = false) -> [UInt8] {
        var builder = ByteArrayBuilder(initialCapacity: length)
        var escaped = false
        var quoted = false

        let end = startIndex + length
        guard startIndex >= 0, length >= 0, end <= bytes.count else {
            return []
        }

        for index in startIndex..<end {
            let byte = bytes[index]
            switch byte {
            case 0x0D, 0x0A:
                escaped = false
            case 0x09:
                builder.append(convertTabsToSpaces ? 0x20 : 0x09)
                escaped = false
            case 0x5C:
                if escaped {
                    builder.append(0x5C)
                }
                escaped.toggle()
            case 0x22:
                if escaped {
                    builder.append(0x22)
                    escaped = false
                } else {
                    quoted.toggle()
                }
            default:
                builder.append(byte)
                escaped = false
            }
        }

        _ = quoted
        return builder.toArray()
    }

    /// Enumerates Message-Id references from a string value.
    ///
    /// Parses Message-Id references such as those found in the In-Reply-To
    /// or References headers of MIME messages.
    ///
    /// - Parameter value: The text containing Message-Id references.
    /// - Returns: An array of parsed Message-Id values (without angle brackets).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let refs = MimeUtils.enumerateReferences("<abc@example.com> <def@example.com>")
    /// // Returns: ["abc@example.com", "def@example.com"]
    /// ```
    static func enumerateReferences(_ value: String) -> [String] {
        let buffer = CharsetUtils.getBytes(value, encoding: .utf8)
        return enumerateReferences(buffer, startIndex: 0, length: buffer.count)
    }

    /// Enumerates Message-Id references from a raw byte buffer.
    ///
    /// Incrementally parses Message-Id values (such as those from a References header
    /// in a MIME message) from the supplied buffer starting at the given index
    /// and spanning across the specified number of bytes.
    ///
    /// - Parameters:
    ///   - buffer: The raw byte buffer to parse.
    ///   - startIndex: The index into the buffer to start parsing.
    ///   - length: The number of bytes to parse.
    /// - Returns: An array of parsed Message-Id values (without angle brackets).
    static func enumerateReferences(_ buffer: [UInt8], startIndex: Int, length: Int) -> [String] {
        var references: [String] = []
        let endIndex = startIndex + length
        var index = startIndex

        guard startIndex >= 0, length >= 0, endIndex <= buffer.count else {
            return []
        }

        while index < endIndex {
            do {
                _ = try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: false)
            } catch {
                break
            }

            if index >= endIndex {
                break
            }

            if buffer[index] == 0x3C {
                var msgid: String? = nil
                if (try? ParseUtils.tryParseMsgId(buffer, index: &index, endIndex: endIndex, requireAngleAddr: true, throwOnError: false, msgid: &msgid)) == true {
                    if let msgid {
                        references.append(msgid)
                    }
                } else {
                    index += 1
                }
            } else {
                if (try? ParseUtils.skipWord(buffer, index: &index, endIndex: endIndex, throwOnError: false)) != true {
                    index += 1
                }
            }
        }

        return references
    }

    /// Parses a Message-Id or Content-Id header value from a byte buffer.
    ///
    /// Parses the Message-Id (or Content-Id) value, returning the addr-spec
    /// portion of the msg-id token (i.e., the part between angle brackets).
    ///
    /// - Parameters:
    ///   - buffer: The raw byte buffer to parse.
    ///   - startIndex: The index into the buffer to start parsing.
    ///   - length: The number of bytes to parse.
    /// - Returns: The addr-spec portion of the msg-id token, or `nil` if parsing failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let buffer = Array("<abc123@example.com>".utf8)
    /// let msgId = MimeUtils.parseMessageId(buffer, startIndex: 0, length: buffer.count)
    /// // Returns: "abc123@example.com"
    /// ```
    static func parseMessageId(_ buffer: [UInt8], startIndex: Int, length: Int) -> String? {
        let endIndex = startIndex + length
        var index = startIndex
        var msgid: String? = nil

        guard startIndex >= 0, length >= 0, endIndex <= buffer.count else {
            return nil
        }

        _ = try? ParseUtils.tryParseMsgId(buffer, index: &index, endIndex: endIndex, requireAngleAddr: false, throwOnError: false, msgid: &msgid)
        return msgid
    }

    /// Parses a Message-Id or Content-Id header value from a string.
    ///
    /// Parses the Message-Id (or Content-Id) value, returning the addr-spec
    /// portion of the msg-id token (i.e., the part between angle brackets).
    ///
    /// - Parameter text: The text to parse.
    /// - Returns: The addr-spec portion of the msg-id token, or `nil` if parsing failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let msgId = MimeUtils.parseMessageId("<abc123@example.com>")
    /// // Returns: "abc123@example.com"
    /// ```
    static func parseMessageId(_ text: String) -> String? {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        return parseMessageId(buffer, startIndex: 0, length: buffer.count)
    }

    /// Tries to parse a version from a byte buffer (such as a MIME-Version header).
    ///
    /// Parses a MIME version string from the supplied buffer starting at the given index
    /// and spanning across the specified number of bytes.
    ///
    /// - Parameters:
    ///   - buffer: The raw byte buffer to parse.
    ///   - startIndex: The index into the buffer to start parsing.
    ///   - length: The number of bytes to parse.
    /// - Returns: The parsed ``MimeVersion``, or `nil` if parsing failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let buffer = Array("1.0".utf8)
    /// if let version = MimeUtils.tryParseVersion(buffer, startIndex: 0, length: buffer.count) {
    ///     print(version)  // "1.0"
    /// }
    /// ```
    static func tryParseVersion(_ buffer: [UInt8], startIndex: Int, length: Int) -> MimeVersion? {
        let endIndex = startIndex + length
        var index = startIndex
        var values: [Int] = []

        guard startIndex >= 0, length >= 0, endIndex <= buffer.count else {
            return nil
        }

        while index < endIndex {
            do {
                if !(try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: false)) || index >= endIndex {
                    return nil
                }

                var value = 0
                if !ParseUtils.tryParseInt32(buffer, index: &index, endIndex: endIndex, value: &value) {
                    return nil
                }
                values.append(value)

                if !(try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: false)) {
                    return nil
                }

                if index >= endIndex {
                    break
                }

                if buffer[index] != 0x2E {
                    return nil
                }
                index += 1
            } catch {
                return nil
            }
        }

        return MimeVersion(components: values)
    }

    /// Tries to parse a version from a string (such as a MIME-Version header value).
    ///
    /// Parses a MIME version string from the specified text.
    ///
    /// - Parameter text: The text to parse.
    /// - Returns: The parsed ``MimeVersion``, or `nil` if parsing failed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let version = MimeUtils.tryParseVersion("1.0") {
    ///     print(version)  // "1.0"
    /// }
    /// ```
    static func tryParseVersion(_ text: String) -> MimeVersion? {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        return tryParseVersion(buffer, startIndex: 0, length: buffer.count)
    }

    /// Quotes the specified text and appends it to a string builder.
    ///
    /// Quotes the specified text by enclosing it in double-quotes and escaping
    /// any backslashes and double-quotes within, then appends the result to the builder.
    ///
    /// - Parameters:
    ///   - builder: The string to append the quoted text to.
    ///   - text: The text to quote.
    static func appendQuoted(_ builder: inout String, _ text: String) {
        builder.append(quote(text))
    }

    /// Generates a Message-Id or Content-Id.
    ///
    /// Generates a new Message-Id (or Content-Id) using the supplied domain.
    /// If no domain is provided or the domain is empty, "localhost" is used.
    ///
    /// - Parameter domain: A domain to use for the Message-Id. If `nil` or empty,
    ///   "localhost" is used as the default.
    /// - Returns: A unique message identifier in the format `uuid@domain`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let messageId = MimeUtils.generateMessageId("example.com")
    /// // e.g., "550e8400-e29b-41d4-a716-446655440000@example.com"
    ///
    /// let defaultId = MimeUtils.generateMessageId()
    /// // e.g., "550e8400-e29b-41d4-a716-446655440000@localhost"
    /// ```
    static func generateMessageId(_ domain: String? = nil) -> String {
        let trimmed = domain?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = (trimmed?.isEmpty == false) ? trimmed! : "localhost"
        let encoded = MailboxAddress.idnMapping.encode(host).lowercased()
        return "\(UUID().uuidString)@\(encoded)"
    }

    /// Generates a Message-Id or Content-Id with domain validation.
    ///
    /// Generates a new Message-Id (or Content-Id) using the supplied domain,
    /// throwing an error if the domain is empty or contains only whitespace.
    ///
    /// - Parameter domain: A non-empty domain to use for the Message-Id.
    /// - Returns: A unique message identifier in the format `uuid@domain`.
    /// - Throws: ``MimeUtilsError/invalidArgument`` if the domain is empty
    ///   or contains only whitespace.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let messageId = try MimeUtils.generateMessageId(validating: "example.com")
    /// } catch MimeUtilsError.invalidArgument {
    ///     print("Invalid domain provided")
    /// }
    /// ```
    static func generateMessageId(validating domain: String) throws -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MimeUtilsError.invalidArgument
        }
        return generateMessageId(trimmed)
    }
}
