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
// GroupAddress.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An address group, as specified by rfc0822.
///
/// Group addresses are rarely used anymore. Typically, if you see a group address,
/// it will be of the form: `"undisclosed-recipients: ;"`.
public final class GroupAddress: InternetAddress {
    /// The members of the group.
    ///
    /// Represents the member addresses of the group. If the group address properly conforms
    /// to the internet standards, every group member should be of the ``MailboxAddress``
    /// variety. When handling group addresses constructed by third-party software, it is possible
    /// for groups to contain members of the ``GroupAddress`` variety.
    ///
    /// When constructing new messages, it is recommended that address groups not contain
    /// anything other than ``MailboxAddress`` members in order to comply with internet
    /// standards.
    public private(set) var members: InternetAddressList

    /// Initializes a new instance of the ``GroupAddress`` class.
    ///
    /// Creates a new ``GroupAddress`` with the specified name and list of addresses. The
    /// specified text encoding is used when encoding the name according to the rules of rfc2047.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the group.
    ///   - members: A list of addresses.
    public init(encoding: String.Encoding, name: String?, members: InternetAddressList) {
        self.members = members
        super.init(encoding: encoding, name: name)
        self.members.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    /// Initializes a new instance of the ``GroupAddress`` class.
    ///
    /// Creates a new ``GroupAddress`` with the specified name and list of addresses.
    ///
    /// - Parameters:
    ///   - name: The name of the group.
    ///   - members: A list of addresses.
    public convenience init(name: String?, members: [InternetAddress]) {
        self.init(encoding: .utf8, name: name, members: InternetAddressList(members))
    }

    /// Initializes a new instance of the ``GroupAddress`` class.
    ///
    /// Creates a new ``GroupAddress`` with the specified name. The specified
    /// text encoding is used when encoding the name according to the rules of rfc2047.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the group.
    public override init(encoding: String.Encoding, name: String?) {
        self.members = InternetAddressList()
        super.init(encoding: encoding, name: name)
        self.members.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    /// Initializes a new instance of the ``GroupAddress`` class.
    ///
    /// Creates a new ``GroupAddress`` with the specified name.
    ///
    /// - Parameter name: The name of the group.
    public convenience init(name: String?) {
        self.init(encoding: .utf8, name: name)
    }

    /// Clones the group address.
    ///
    /// - Returns: The cloned group address.
    public override func copy() -> InternetAddress {
        let copiedMembers = members.map { $0.copy() }
        return GroupAddress(encoding: encoding, name: name, members: InternetAddressList(copiedMembers))
    }

    internal override func encode(_ options: FormatOptions, builder: inout String, firstToken: inout Bool, lineLength: inout Int) {
        if let name = name, !name.isEmpty {
            let formattedName: String
            if !options.international {
                formattedName = Rfc2047.encodePhraseAsString(options, encoding, name)
            } else {
                formattedName = InternetAddress.encodeInternationalizedPhrase(name)
            }

            if lineLength + formattedName.count > options.maxLineLength {
                if formattedName.count > options.maxLineLength {
                    StringBuilderUtils.appendFolded(&builder, options: options, firstToken: &firstToken, value: formattedName, lineLength: &lineLength)
                } else {
                    if !firstToken && lineLength > 1 {
                        StringBuilderUtils.lineWrap(&builder, options: options)
                        lineLength = 1
                    }
                    lineLength += formattedName.count
                    builder.append(formattedName)
                }
            } else {
                lineLength += formattedName.count
                builder.append(formattedName)
            }
        }

        builder.append(": ")
        lineLength += 2

        members.encode(options, builder: &builder, firstToken: false, lineLength: &lineLength)

        builder.append(";")
        lineLength += 1
    }

    /// Returns a string representation of the ``GroupAddress``, optionally encoding it for transport.
    ///
    /// Returns a string containing the formatted group of addresses. If the `encoded`
    /// parameter is `true`, then the name of the group and all member addresses will be encoded
    /// according to the rules defined in rfc2047, otherwise the names will not be encoded at all and
    /// will therefore only be suitable for display purposes.
    ///
    /// - Parameters:
    ///   - options: The formatting options.
    ///   - encoded: If `true`, the ``GroupAddress`` will be encoded for transport.
    /// - Returns: A string representing the ``GroupAddress``.
    public override func formatted(with options: FormatOptions = .default, encoded: Bool = false) -> String {
        if encoded {
            var builder = ""
            var lineLength = 0
            var firstToken = true
            self.encode(options, builder: &builder, firstToken: &firstToken, lineLength: &lineLength)
            return builder
        }

        var builder = ""
        builder.append(name ?? "")
        builder.append(": ")
        for (index, address) in members.enumerated() {
            if index > 0 {
                builder.append(", ")
            }
            builder.append(address.description)
        }
        builder.append(";")
        return builder
    }

    /// Determines whether the specified ``GroupAddress`` is equal to the current ``GroupAddress``.
    ///
    /// Compares two group addresses to determine if they are identical or not.
    ///
    /// - Parameter other: The ``InternetAddress`` to compare with the current ``GroupAddress``.
    /// - Returns: `true` if the specified address is equal to the current ``GroupAddress``; otherwise, `false`.
    internal override func isEqual(to other: InternetAddress?) -> Bool {
        guard let group = other as? GroupAddress else {
            return false
        }
        return name == group.name && members == group.members
    }

    // MARK: Parsing APIs

    internal static func tryParse(_ options: ParserOptions, _ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool, group: inout GroupAddress?) throws -> Bool {
        if let overflow = findGroupDepthOverflow(text, startIndex: index, endIndex: endIndex, maxDepth: options.maxAddressGroupDepth) {
            if throwOnError {
                throw ParseException("Exceeded maximum rfc822 group depth at offset \(overflow.tokenIndex)", tokenIndex: overflow.tokenIndex, errorIndex: overflow.errorIndex)
            }
            group = nil
            return false
        }
        var flags: AddressParserFlags = [.allowGroupAddress]
        if throwOnError {
            flags.insert(.throwOnError)
        }

        var address: InternetAddress? = nil
        if !(try InternetAddress.tryParse(flags, options, text, index: &index, endIndex: endIndex, groupDepth: 0, address: &address)) {
            group = nil
            return false
        }

        group = address as? GroupAddress
        return group != nil
    }

    private static func findGroupDepthOverflow(_ text: [UInt8], startIndex: Int, endIndex: Int, maxDepth: Int) -> (tokenIndex: Int, errorIndex: Int)? {
        if maxDepth <= 0 {
            return (startIndex, startIndex)
        }

        var depth = 0
        var tokenStart: Int? = nil
        var previousWasDelimiter = true
        var inQuote = false
        var escaped = false
        var commentDepth = 0
        var angleDepth = 0

        var index = startIndex
        while index < endIndex {
            let byte = text[index]

            if inQuote {
                if escaped {
                    escaped = false
                } else if byte == 0x5C { // '\\'
                    escaped = true
                } else if byte == 0x22 { // '\"'
                    inQuote = false
                }
                index += 1
                continue
            }

            if commentDepth > 0 {
                if byte == 0x28 { // '('
                    commentDepth += 1
                } else if byte == 0x29 { // ')'
                    commentDepth -= 1
                }
                index += 1
                continue
            }

            if angleDepth > 0 {
                if byte == 0x3C { // '<'
                    angleDepth += 1
                } else if byte == 0x3E { // '>'
                    angleDepth -= 1
                }
                index += 1
                continue
            }

            switch byte {
            case 0x22: // '\"'
                inQuote = true
                escaped = false
                previousWasDelimiter = true
                tokenStart = nil
            case 0x28: // '('
                commentDepth = 1
                previousWasDelimiter = true
                tokenStart = nil
            case 0x3C: // '<'
                angleDepth = 1
                previousWasDelimiter = true
                tokenStart = nil
            case 0x3A: // ':'
                if depth >= maxDepth {
                    let tokenIndex = tokenStart ?? index
                    return (tokenIndex, index)
                }
                depth += 1
                previousWasDelimiter = true
                tokenStart = nil
            case 0x3B: // ';'
                if depth > 0 {
                    depth -= 1
                }
                previousWasDelimiter = true
                tokenStart = nil
            case 0x2C: // ','
                previousWasDelimiter = true
                tokenStart = nil
            default:
                if ByteClassification.isWhitespace(byte) {
                    previousWasDelimiter = true
                    tokenStart = nil
                } else if previousWasDelimiter {
                    tokenStart = index
                    previousWasDelimiter = false
                }
            }

            index += 1
        }

        return nil
    }

    // MARK: - Swift-Idiomatic Parsing Initializers

    /// Parses the given text into a new ``GroupAddress`` instance.
    ///
    /// Parses a single ``GroupAddress``. If the address is not a group address or
    /// there is more than a single group address, then parsing will fail.
    ///
    /// Use `try?` for optional behavior: `let grp = try? GroupAddress(parsing: text)`
    ///
    /// - Parameters:
    ///   - text: The text to parse.
    ///   - options: The parser options to use.
    /// - Throws: ``ParseException`` if the text could not be parsed.
    public convenience init(parsing text: String, options: ParserOptions = .default) throws {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        try self.init(parsing: buffer, options: options)
    }

    /// Parses the given input buffer into a new ``GroupAddress`` instance.
    ///
    /// Parses a single ``GroupAddress``. If the address is not a group address or
    /// there is more than a single group address, then parsing will fail.
    ///
    /// Use `try?` for optional behavior: `let grp = try? GroupAddress(parsing: buffer)`
    ///
    /// - Parameters:
    ///   - buffer: The input buffer to parse.
    ///   - options: The parser options to use.
    /// - Throws: ``ParseException`` if the buffer could not be parsed.
    public convenience init(parsing buffer: [UInt8], options: ParserOptions = .default) throws {
        var group: GroupAddress? = nil
        var index = 0
        let endIndex = buffer.count

        // First try with throwOnError: false to allow lenient parsing of incomplete groups
        if !(try Self.tryParse(options, buffer, index: &index, endIndex: endIndex, throwOnError: false, group: &group)) {
            // If that fails, try with throwOnError: true to get the proper exception
            index = 0
            _ = try Self.tryParse(options, buffer, index: &index, endIndex: endIndex, throwOnError: true, group: &group)
        }

        _ = try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: true)

        if index != endIndex {
            throw ParseException("Unexpected token at offset \(index)", tokenIndex: index, errorIndex: index)
        }

        guard let parsed = group else {
            throw ParseException("Invalid group address.", tokenIndex: 0, errorIndex: index)
        }

        self.init(encoding: parsed.encoding, name: parsed.name, members: parsed.members)
    }
}
