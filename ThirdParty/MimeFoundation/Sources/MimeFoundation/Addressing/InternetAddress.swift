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
// InternetAddress.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An abstract internet address, as specified by rfc0822.
///
/// An ``InternetAddress`` can be any type of address defined by the original Internet Message specification.
///
/// There are effectively two types of addresses: mailboxes and groups.
///
/// Mailbox addresses are what are most commonly known as email addresses and are
/// represented by the ``MailboxAddress`` class.
///
/// Group addresses are themselves lists of addresses and are represented by the
/// ``GroupAddress`` class. While rare, it is still important to handle these
/// types of addresses. They typically only contain mailbox addresses, but may also
/// contain other group addresses.
public class InternetAddress: Comparable, Equatable, CustomStringConvertible {
    private static let atomSpecials = "()<>@,;:\\\".[]"

    private var encodingStorage: String.Encoding
    private var nameStorage: String?

    /// The character encoding to use when encoding the name of the address.
    ///
    /// The character encoding is used to convert the ``name`` property, if it is set,
    /// to a stream of bytes when encoding the internet address for transport.
    public var encoding: String.Encoding {
        get { encodingStorage }
        set {
            guard encodingStorage != newValue else { return }
            encodingStorage = newValue
            onChanged()
        }
    }

    /// The display name of the address.
    ///
    /// A name is optional and is typically set to the name of the person
    /// or group that own the internet address.
    ///
    /// For example, the ``name`` property of the following ``MailboxAddress`` would be `"John Smith"`.
    ///
    /// `John Smith <j.smith@example.com>`
    ///
    /// Likewise, the ``name`` property of the following ``GroupAddress`` would be `"undisclosed-recipients"`.
    ///
    /// `undisclosed-recipients: Alice <alice@wonderland.com>, Bob <bob@the-builder.com>;`
    public var name: String? {
        get { nameStorage }
        set {
            guard nameStorage != newValue else { return }
            nameStorage = newValue
            onChanged()
        }
    }

    /// Initializes a new instance of the ``InternetAddress`` class.
    ///
    /// Initializes the ``encoding`` and ``name`` properties of the internet address.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the mailbox or group.
    public init(encoding: String.Encoding, name: String?) {
        self.encodingStorage = encoding
        self.nameStorage = name
    }

    /// Clones the address.
    ///
    /// - Returns: The cloned address.
    public func copy() -> InternetAddress {
        fatalError("Subclasses must override copy().")
    }

    internal func encode(_ options: FormatOptions, builder: inout String, firstToken: inout Bool, lineLength: inout Int) {
        fatalError("Subclasses must override encode().")
    }

    /// Serializes the ``InternetAddress`` to a string, optionally encoding it for transport.
    ///
    /// If the `encoded` parameter is `true`, then this method will return
    /// an encoded version of the internet address according to the rules described in rfc2047.
    ///
    /// However, if the `encoded` parameter is `false`, then this method will
    /// return a string suitable only for display purposes.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - encoded: If `true`, the ``InternetAddress`` will be encoded for transport.
    /// - Returns: A string representing the ``InternetAddress``.
    public func formatted(with options: FormatOptions = .default, encoded: Bool = false) -> String {
        fatalError("Subclasses must override formatted(with:encoded:).")
    }

    /// A string representation of the ``InternetAddress`` suitable for display.
    public var description: String {
        formatted(with: .default, encoded: false)
    }

    internal var changed: ((InternetAddress) -> Void)?

    /// Raises the internal changed event used to keep headers in sync.
    ///
    /// This method is called whenever a property of the internet address is changed.
    internal func onChanged() {
        changed?(self)
    }

    /// Compares two internet addresses for sorting purposes.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side address.
    ///   - rhs: The right-hand side address.
    /// - Returns: `true` if `lhs` should be ordered before `rhs`; otherwise, `false`.
    public static func < (lhs: InternetAddress, rhs: InternetAddress) -> Bool {
        lhs.compare(to: rhs) < 0
    }

    /// Determines whether two internet addresses are equal.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side address.
    ///   - rhs: The right-hand side address.
    /// - Returns: `true` if the addresses are equal; otherwise, `false`.
    public static func == (lhs: InternetAddress, rhs: InternetAddress) -> Bool {
        lhs.isEqual(to: rhs)
    }

    /// Compares two internet addresses for the purpose of sorting.
    ///
    /// - Parameter other: The internet address to compare to.
    /// - Returns: The sort order of the current internet address compared to the other internet address.
    internal func compare(to other: InternetAddress) -> Int {
        let lhsName = name ?? ""
        let rhsName = other.name ?? ""
        let nameCompare = lhsName.caseInsensitiveCompare(rhsName)
        if nameCompare != .orderedSame {
            return nameCompare == .orderedAscending ? -1 : 1
        }

        if let mailbox = self as? MailboxAddress, let otherMailbox = other as? MailboxAddress {
            let address = mailbox.address
            let otherAddress = otherMailbox.address
            let at = address.firstIndex(of: "@")
            let otherAt = otherAddress.firstIndex(of: "@")

            if let at = at, let otherAt = otherAt {
                let domain = address[address.index(after: at)...]
                let otherDomain = otherAddress[otherAddress.index(after: otherAt)...]
                let compare = domain.lowercased().compare(otherDomain.lowercased())
                if compare != .orderedSame {
                    return compare == .orderedAscending ? -1 : 1
                }
            }

            let local = at == nil ? address : String(address[..<at!])
            let otherLocal = otherAt == nil ? otherAddress : String(otherAddress[..<otherAt!])
            let localCompare = local.lowercased().compare(otherLocal.lowercased())
            if localCompare != .orderedSame {
                return localCompare == .orderedAscending ? -1 : 1
            }
            return local.count - otherLocal.count
        }

        if self is MailboxAddress, other is GroupAddress {
            return -1
        }

        if self is GroupAddress, other is MailboxAddress {
            return 1
        }

        return 0
    }

    /// Determines whether the specified ``InternetAddress`` is equal to the current ``InternetAddress``.
    ///
    /// Compares two internet addresses to determine if they are identical or not.
    ///
    /// - Parameter other: The ``InternetAddress`` to compare with the current ``InternetAddress``.
    /// - Returns: `true` if the specified ``InternetAddress`` is equal to the current ``InternetAddress``; otherwise, `false`.
    internal func isEqual(to other: InternetAddress?) -> Bool {
        return false
    }

    /// Encodes an internationalized phrase, quoting it if necessary.
    ///
    /// - Parameter phrase: The phrase to encode.
    /// - Returns: The encoded phrase.
    internal static func encodeInternationalizedPhrase(_ phrase: String) -> String {
        for ch in phrase {
            if atomSpecials.contains(ch) {
                return MimeUtils.quote(phrase)
            }
        }
        return phrase
    }

    // MARK: Parsing

    internal static func tryParseLocalPart(_ text: [UInt8], index: inout Int, endIndex: Int, compliance: RfcComplianceMode, skipTrailingCfws: Bool, throwOnError: Bool, localpart: inout String?) throws -> Bool {
        var token = ValueStringBuilder(initialCapacity: 128)
        let startIndex = index
        localpart = nil

        repeat {
            var escapedAt = false
            let start = index

            if text[index] == 0x22 {
                if !(try ParseUtils.skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }
            } else if ByteClassification.isAtom(text[index]) {
                if !ParseUtils.skipAtom(text, index: &index, endIndex: endIndex) {
                    return false
                }

                if compliance == .looser {
                    while index + 1 < endIndex && text[index] == 0x5C && text[index + 1] == 0x40 {
                        escapedAt = true
                        index += 2
                        if !ParseUtils.skipAtom(text, index: &index, endIndex: endIndex) {
                            break
                        }
                    }
                }
            } else {
                if throwOnError {
                    throw ParseException("Invalid local-part at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            let word: String
            if let decoded = try? CharsetUtils.getString(text, start: start, length: index - start, encoding: .utf8) {
                word = decoded
            } else {
                if compliance == .strict {
                    if throwOnError {
                        throw ParseException("Internationalized local-part tokens may only contain UTF-8 characters.", tokenIndex: start, errorIndex: start)
                    }
                    return false
                }
                word = CharsetUtils.tryGetString(text, start: start, length: index - start, encoding: .isoLatin1) ?? ""
            }

            if escapedAt {
                token.append(word.replacingOccurrences(of: "\\@", with: "%40"))
            } else {
                token.append(word)
            }

            let cfws = index
            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex || text[index] != 0x2E {
                if !skipTrailingCfws {
                    index = cfws
                }
                break
            }

            repeat {
                token.append(".")
                index += 1

                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }

                if index >= endIndex {
                    if throwOnError {
                        throw ParseException("Incomplete local-part at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                    }
                    return false
                }
            } while compliance == .looser && text[index] == 0x2E

            if compliance == .looser && (index >= endIndex || text[index] == 0x40) {
                break
            }
        } while true

        localpart = token.asString()
        return true
    }

    private static let commaGreaterThanOrSemiColon: [UInt8] = [0x2C, 0x3E, 0x3B]

    internal static func tryParseAddrspec(_ text: [UInt8], index: inout Int, endIndex: Int, sentinels: [UInt8], compliance: RfcComplianceMode, throwOnError: Bool, addrspec: inout String?, at: inout Int) throws -> Bool {
        let startIndex = index
        addrspec = nil
        at = -1

        var localpart: String? = nil
        if !(try tryParseLocalPart(text, index: &index, endIndex: endIndex, compliance: compliance, skipTrailingCfws: true, throwOnError: throwOnError, localpart: &localpart)) {
            return false
        }

        if index >= endIndex || ParseUtils.isSentinel(text[index], sentinels) {
            addrspec = localpart
            return true
        }

        if text[index] != 0x40 {
            if throwOnError {
                throw ParseException("Invalid addr-spec token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        index += 1
        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete addr-spec token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete addr-spec token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        var domain: String? = nil
        if !(try ParseUtils.tryParseDomain(text, index: &index, endIndex: endIndex, sentinels: sentinels, throwOnError: throwOnError, domain: &domain)) {
            return false
        }

        var domainValue = domain ?? ""
        if ParseUtils.isIdnEncoded(domainValue) {
            domainValue = MailboxAddress.idnMapping.decode(domainValue)
        }

        let local = localpart ?? ""
        addrspec = local + "@" + domainValue
        at = local.count
        return true
    }

    internal static func tryParseMailbox(_ options: ParserOptions, _ text: [UInt8], startIndex: Int, index: inout Int, endIndex: Int, name: String, codepage: Int, throwOnError: Bool, address: inout InternetAddress?) throws -> Bool {
        let encoding = CharsetUtils.getEncodingOrDefault(codepage, fallback: .utf8)
        var route: DomainList? = nil
        address = nil

        index += 1 // skip '<'

        if index < endIndex && text[index] == 0x3C {
            if options.addressParserComplianceMode == .strict {
                if throwOnError {
                    throw ParseException("Excessive angle brackets at offset \(index)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
            while index < endIndex && text[index] == 0x3C {
                index += 1
            }
        }

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete mailbox at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        if text[index] == 0x40 {
            let routeParsed = (try? DomainList.tryParse(text, index: &index, endIndex: endIndex, throwOnError: false, route: &route)) ?? false
            if !routeParsed {
                if throwOnError {
                    throw ParseException("Invalid route in mailbox at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            if index >= endIndex || text[index] != 0x3A {
                if throwOnError {
                    throw ParseException("Incomplete route in mailbox at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            index += 1
            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex {
                if throwOnError {
                    throw ParseException("Incomplete mailbox at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
        }

        var addrspec: String? = nil
        var atIndex = -1
        if !(try tryParseAddrspec(text, index: &index, endIndex: endIndex, sentinels: commaGreaterThanOrSemiColon, compliance: options.addressParserComplianceMode, throwOnError: throwOnError, addrspec: &addrspec, at: &atIndex)) {
            return false
        }

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex || text[index] != 0x3E {
            if options.addressParserComplianceMode == .strict {
                if throwOnError {
                    throw ParseException("Unexpected end of mailbox at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
        } else {
            index += 1
            if index < endIndex && text[index] == 0x3E {
                if options.addressParserComplianceMode == .strict {
                    if throwOnError {
                        throw ParseException("Excessive angle brackets at offset \(index)", tokenIndex: startIndex, errorIndex: index)
                    }
                    return false
                }
                while index < endIndex && text[index] == 0x3E {
                    index += 1
                }
            }
        }

        if let route = route {
            address = MailboxAddress(encoding: encoding, name: name, route: route, address: addrspec ?? "", at: atIndex)
        } else {
            address = MailboxAddress(encoding: encoding, name: name, address: addrspec ?? "", at: atIndex)
        }
        return true
    }

    private static func tryParseGroup(_ flags: AddressParserFlags, _ options: ParserOptions, _ text: [UInt8], startIndex: Int, index: inout Int, endIndex: Int, groupDepth: Int, name: String, codepage: Int, address: inout InternetAddress?) throws -> Bool {
        let encoding = CharsetUtils.getEncodingOrDefault(codepage, fallback: .utf8)
        let throwOnError = flags.contains(.throwOnError)

        index += 1
        while index < endIndex && (text[index] == 0x3A || ByteClassification.isBlank(text[index])) {
            index += 1
        }

        var members: InternetAddressList? = nil
        let parsedMembers = InternetAddressList.tryParse(flags.union(.allowMailboxAddress), options, text, index: &index, endIndex: endIndex, isGroup: true, groupDepth: groupDepth, addresses: &members)
        if parsedMembers {
            address = GroupAddress(encoding: encoding, name: name, members: members ?? InternetAddressList())
        } else {
            address = GroupAddress(encoding: encoding, name: name)
        }

        var foundSemicolon = false
        if index >= endIndex || text[index] != 0x3B {
            if throwOnError && options.addressParserComplianceMode == .strict {
                throw ParseException("Expected to find ';' at offset \(index)", tokenIndex: startIndex, errorIndex: index)
            }
            while index < endIndex && text[index] != 0x3B {
                index += 1
            }
            if index < endIndex && text[index] == 0x3B {
                foundSemicolon = true
                index += 1
            }
        } else {
            foundSemicolon = true
            index += 1
        }

        if throwOnError && !foundSemicolon && (members == nil || members?.count == 0) {
            throw ParseException("Unexpected end of group at offset \(index)", tokenIndex: index, errorIndex: index)
        }

        return true
    }

    internal static func tryParse(_ flags: AddressParserFlags, _ options: ParserOptions, _ text: [UInt8], index: inout Int, endIndex: Int, groupDepth: Int, address: inout InternetAddress?) throws -> Bool {
        let throwOnError = flags.contains(.throwOnError)
        address = nil

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index == endIndex {
            if throwOnError {
                throw ParseException("No address found.", tokenIndex: index, errorIndex: index)
            }
            return false
        }

        var trimLeadingQuote = false
        let startIndex = index
        var length = 0
        var words = 0

        while index < endIndex {
            let quoted = text[index] == 0x22

            if options.addressParserComplianceMode == .strict {
                if !(try ParseUtils.skipWord(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    break
                }
            } else if text[index] == 0x22 {
                let qstringIndex = index
                if (try? ParseUtils.skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: false)) != true {
                    index = qstringIndex + 1
                    _ = ParseUtils.skipWhiteSpace(text, index: &index, endIndex: endIndex)
                    if !ParseUtils.skipPhraseAtom(text, index: &index, endIndex: endIndex) {
                        if throwOnError {
                            throw ParseException("Incomplete quoted-string token at offset \(qstringIndex)", tokenIndex: qstringIndex, errorIndex: endIndex)
                        }
                        break
                    }
                    if startIndex == qstringIndex {
                        trimLeadingQuote = true
                    }
                }
            } else {
                if !ParseUtils.skipPhraseAtom(text, index: &index, endIndex: endIndex) {
                    break
                }
            }

            length = index - startIndex

            repeat {
                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }

                if index >= endIndex || text[index] != 0x2E {
                    break
                }

                index += 1
                length = index - startIndex
            } while true

            words += 1

            if options.allowUnquotedCommasInAddresses && index < endIndex && text[index] == 0x2C && !quoted {
                index += 1
                length = index - startIndex
                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }
            }
        }

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex || text[index] == 0x2C || text[index] == 0x3E || text[index] == 0x3B {
            let sentinel: UInt8 = index < endIndex ? text[index] : 0x2C
            if !flags.contains(.allowMailboxAddress) {
                if throwOnError {
                    throw ParseException("Addr-spec token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
            if !options.allowAddressesWithoutDomain {
                if throwOnError {
                    throw ParseException("Incomplete addr-spec token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            index = startIndex
            var addrspec: String? = nil
            if !(try tryParseLocalPart(text, index: &index, endIndex: endIndex, compliance: options.addressParserComplianceMode, skipTrailingCfws: false, throwOnError: throwOnError, localpart: &addrspec)) {
                return false
            }

            _ = ParseUtils.skipWhiteSpace(text, index: &index, endIndex: endIndex)
            var name = ""
            if index < endIndex && text[index] == 0x28 {
                let comment = index + 1
                _ = ParseUtils.skipComment(text, index: &index, endIndex: endIndex)
                name = Rfc2047.decodePhrase(options, text, startIndex: comment, count: (index - 1) - comment).trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)
            }

            if index < endIndex && text[index] == 0x3E {
                if options.addressParserComplianceMode == .strict {
                    if throwOnError {
                        throw ParseException("Unexpected '>' token at offset \(index)", tokenIndex: startIndex, errorIndex: index)
                    }
                    return false
                }
                index += 1
            }

            if index < endIndex && text[index] != sentinel {
                if throwOnError {
                    throw ParseException("Unexpected '\(Character(UnicodeScalar(text[index])))' token at offset \(index)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            address = MailboxAddress(encoding: .utf8, name: name, address: addrspec ?? "", at: -1)
            return true
        }

        if text[index] == 0x3A {
            if !flags.contains(.allowGroupAddress) {
                if throwOnError {
                    throw ParseException("Group address token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }
            if groupDepth >= options.maxAddressGroupDepth {
                if throwOnError {
                    throw ParseException("Exceeded maximum rfc822 group depth at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            var nameIndex = startIndex
            var codepage = 65001
            var groupName = ""
            if trimLeadingQuote {
                nameIndex += 1
                length -= 1
            }

            if length > 0 {
                groupName = Rfc2047.decodePhrase(options, text, startIndex: nameIndex, count: length, codepage: &codepage)
            }

            let unquotedName = MimeUtils.unquote(groupName, convertTabsToSpaces: true)
            return try tryParseGroup(flags, options, text, startIndex: startIndex, index: &index, endIndex: endIndex, groupDepth: groupDepth + 1, name: unquotedName, codepage: codepage, address: &address)
        }

        if !flags.contains(.allowMailboxAddress) {
            if throwOnError {
                throw ParseException("Mailbox address token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        if text[index] == 0x40 {
            var name = ""
            index = startIndex
            var addrspec: String? = nil
            var atIndex = -1
            if !(try tryParseAddrspec(text, index: &index, endIndex: endIndex, sentinels: commaGreaterThanOrSemiColon, compliance: options.addressParserComplianceMode, throwOnError: throwOnError, addrspec: &addrspec, at: &atIndex)) {
                return false
            }

            _ = ParseUtils.skipWhiteSpace(text, index: &index, endIndex: endIndex)
            if index < endIndex && text[index] == 0x28 {
                let comment = index
                if !ParseUtils.skipComment(text, index: &index, endIndex: endIndex) {
                    if throwOnError {
                        throw ParseException("Incomplete comment token at offset \(comment)", tokenIndex: comment, errorIndex: index)
                    }
                    return false
                }
                name = Rfc2047.decodePhrase(options, text, startIndex: comment + 1, count: (index - 1) - (comment + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex {
                address = MailboxAddress(encoding: .utf8, name: name, address: addrspec ?? "", at: atIndex)
                return true
            }

            if text[index] == 0x3C {
                if options.addressParserComplianceMode == .strict {
                    if throwOnError {
                        throw ParseException("Unexpected '<' token at offset \(index)", tokenIndex: startIndex, errorIndex: index)
                    }
                    return false
                }

                var nameEndIndex = index
                while nameEndIndex > startIndex && ByteClassification.isWhitespace(text[nameEndIndex - 1]) {
                    nameEndIndex -= 1
                }
                length = nameEndIndex - startIndex
            } else {
                if text[index] == 0x3E {
                    if options.addressParserComplianceMode == .strict {
                        if throwOnError {
                            throw ParseException("Unexpected '>' token at offset \(index)", tokenIndex: startIndex, errorIndex: index)
                        }
                        return false
                    }
                    index += 1
                }

                address = MailboxAddress(encoding: .utf8, name: name, address: addrspec ?? "", at: atIndex)
                return true
            }
        }

        if text[index] == 0x3C {
            var nameIndex = startIndex
            var codepage = 65001
            var displayName = ""
            if trimLeadingQuote {
                nameIndex += 1
                length -= 1
            }

            if length > 0 {
                let unquotedBytes = MimeUtils.unquote(text, startIndex: nameIndex, length: length, convertTabsToSpaces: true)
                displayName = Rfc2047.decodePhrase(options, unquotedBytes, startIndex: 0, count: unquotedBytes.count, codepage: &codepage)
            }

            return try tryParseMailbox(options, text, startIndex: startIndex, index: &index, endIndex: endIndex, name: displayName, codepage: codepage, throwOnError: throwOnError, address: &address)
        }

        if throwOnError {
            throw ParseException("Invalid address token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
        }
        return false
    }

    // MARK: Public Parsing APIs

    // MARK: - Swift-Idiomatic Parsing Factory Methods

    /// Parses the given text into a new ``InternetAddress`` instance.
    ///
    /// Parses a single ``MailboxAddress`` or ``GroupAddress``. If the text contains
    /// more data, then parsing will fail.
    ///
    /// Use `try?` for optional behavior: `let addr = try? InternetAddress.parsed(from: text)`
    ///
    /// - Parameters:
    ///   - text: The text to parse.
    ///   - options: The parser options to use.
    /// - Returns: The parsed ``InternetAddress`` (either ``MailboxAddress`` or ``GroupAddress``).
    /// - Throws: ``ParseException`` if the text could not be parsed.
    public static func parsed(from text: String, options: ParserOptions = .default) throws -> InternetAddress {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        return try parsed(from: buffer, options: options)
    }

    /// Parses the given input buffer into a new ``InternetAddress`` instance.
    ///
    /// Parses a single ``MailboxAddress`` or ``GroupAddress``. If the buffer contains
    /// more data, then parsing will fail.
    ///
    /// Use `try?` for optional behavior: `let addr = try? InternetAddress.parsed(from: buffer)`
    ///
    /// - Parameters:
    ///   - buffer: The input buffer to parse.
    ///   - options: The parser options to use.
    /// - Returns: The parsed ``InternetAddress`` (either ``MailboxAddress`` or ``GroupAddress``).
    /// - Throws: ``ParseException`` if the buffer could not be parsed.
    public static func parsed(from buffer: [UInt8], options: ParserOptions = .default) throws -> InternetAddress {
        var index = 0
        let endIndex = buffer.count
        var address: InternetAddress? = nil

        // First try with tryParse (no throwOnError) to allow lenient parsing of incomplete groups
        if !(try tryParse(.tryParse, options, buffer, index: &index, endIndex: endIndex, groupDepth: 0, address: &address)) {
            // If that fails, try with parse (throwOnError) to get the proper exception
            index = 0
            _ = try tryParse(.parse, options, buffer, index: &index, endIndex: endIndex, groupDepth: 0, address: &address)
        }

        _ = try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: true)

        if index != endIndex {
            throw ParseException("Unexpected token at offset \(index)", tokenIndex: index, errorIndex: index)
        }

        guard let address else {
            throw ParseException("Invalid address.", tokenIndex: 0, errorIndex: index)
        }

        return address
    }
}
