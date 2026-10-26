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
// MailboxAddress.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A mailbox address, as specified by rfc822.
///
/// Represents a mailbox address (commonly referred to as an email address)
/// for a single recipient.
public class MailboxAddress: InternetAddress, Hashable {
    private static let emptySentinels: [UInt8] = []

    /// The punycode implementation used for encoding and decoding mailbox addresses.
    ///
    /// Gets or sets the punycode implementation that should be used for encoding and decoding
    /// internationalized domain names in mailbox addresses.
    public static let idnMapping: PunycodeCoding = Punycode()

    private var addressStorage: String
    private var atIndex: Int

    /// The mailbox route.
    ///
    /// A route is a convention that is rarely seen in modern email systems, but is supported
    /// for compatibility with email archives.
    public private(set) var route: DomainList

    internal init(encoding: String.Encoding, name: String?, route: DomainList, address: String, at: Int) {
        self.route = route
        self.addressStorage = address
        self.atIndex = at
        super.init(encoding: encoding, name: name)
        self.route.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    internal init(encoding: String.Encoding, name: String?, address: String, at: Int) {
        self.route = DomainList()
        self.addressStorage = address
        self.atIndex = at
        super.init(encoding: encoding, name: name)
        self.route.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    /// Initializes a new instance of the ``MailboxAddress`` class.
    ///
    /// Creates a new ``MailboxAddress`` with the specified name, address and route. The
    /// specified text encoding is used when encoding the name according to the rules of rfc2047.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the mailbox.
    ///   - route: The route of the mailbox.
    ///   - address: The address of the mailbox.
    public init(encoding: String.Encoding, name: String?, route: [String], address: String) {
        self.route = DomainList(route)
        self.addressStorage = ""
        self.atIndex = -1
        super.init(encoding: encoding, name: name)
        self.route.changed = { [weak self] _ in
            self?.onChanged()
        }
        self.address = address
    }

    /// Initializes a new instance of the ``MailboxAddress`` class.
    ///
    /// Creates a new ``MailboxAddress`` with the specified name, address and route.
    ///
    /// - Parameters:
    ///   - name: The name of the mailbox.
    ///   - route: The route of the mailbox.
    ///   - address: The address of the mailbox.
    public init(name: String?, route: [String], address: String) {
        self.route = DomainList(route)
        self.addressStorage = ""
        self.atIndex = -1
        super.init(encoding: .utf8, name: name)
        self.route.changed = { [weak self] _ in
            self?.onChanged()
        }
        self.address = address
    }

    /// Initializes a new instance of the ``MailboxAddress`` class.
    ///
    /// Creates a new ``MailboxAddress`` with the specified name and address. The
    /// specified text encoding is used when encoding the name according to the rules of rfc2047.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the mailbox.
    ///   - address: The address of the mailbox.
    public init(encoding: String.Encoding, name: String?, address: String) {
        self.route = DomainList()
        self.addressStorage = ""
        self.atIndex = -1
        super.init(encoding: encoding, name: name)
        self.route.changed = { [weak self] _ in
            self?.onChanged()
        }
        self.address = address
    }

    /// Initializes a new instance of the ``MailboxAddress`` class.
    ///
    /// Creates a new ``MailboxAddress`` with the specified name and address.
    ///
    /// - Parameters:
    ///   - name: The name of the mailbox.
    ///   - address: The address of the mailbox.
    public init(name: String?, address: String) {
        self.route = DomainList()
        self.addressStorage = ""
        self.atIndex = -1
        super.init(encoding: .utf8, name: name)
        self.route.changed = { [weak self] _ in
            self?.onChanged()
        }
        self.address = address
    }

    /// The mailbox address.
    ///
    /// Represents the actual email address and is in the form of `user@domain.com`.
    public var address: String {
        get { addressStorage }
        set {
            do {
                try setAddress(newValue)
            } catch {
                return
            }
        }
    }

    /// Sets the mailbox address with validation.
    ///
    /// - Parameter value: The new address value.
    /// - Throws: ``ParseException`` if the address is malformed.
    public func setAddress(_ value: String) throws {
        if value == addressStorage {
            return
        }

        if value.isEmpty {
            addressStorage = value
            atIndex = -1
            onChanged()
            return
        }

        let buffer = CharsetUtils.getBytes(value, encoding: .utf8)
        var index = 0
        let endIndex = buffer.count
        var addrspec: String? = nil
        var at = -1
        _ = try InternetAddress.tryParseAddrspec(buffer, index: &index, endIndex: endIndex, sentinels: MailboxAddress.emptySentinels, compliance: ParserOptions.default.addressParserComplianceMode, throwOnError: true, addrspec: &addrspec, at: &at)
        _ = try? ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: false)

        if index != endIndex {
            let ch = Character(UnicodeScalar(Int(buffer[index]))!)
            throw ParseException("Unexpected '\(ch)' token at offset \(index)", tokenIndex: index, errorIndex: index)
        }

        addressStorage = addrspec ?? value
        atIndex = at
        onChanged()
    }

    /// The local-part of the email address.
    ///
    /// Gets the local-part of the email address, sometimes referred to as the "user" portion of an email address.
    /// For example, in `user@domain.com`, the local-part would be `user`.
    public var localPart: String {
        if atIndex == -1 {
            return addressStorage
        }
        return String(addressStorage.prefix(atIndex))
    }

    /// The domain of the email address.
    ///
    /// Gets the domain of the email address.
    /// For example, in `user@domain.com`, the domain would be `domain.com`.
    public var domain: String {
        if atIndex == -1 {
            return ""
        }
        return String(addressStorage.suffix(addressStorage.count - atIndex - 1))
    }

    /// Whether the address is an international address.
    ///
    /// International addresses are addresses that contain international
    /// characters in either their local-parts or their domains.
    ///
    /// For more information, see section 3.2 of
    /// [rfc6532](https://tools.ietf.org/html/rfc6532#section-3.2).
    public var isInternational: Bool {
        guard !addressStorage.isEmpty else {
            return false
        }
        if ParseUtils.isInternational(addressStorage) {
            return true
        }
        for domain in route {
            if ParseUtils.isInternational(domain) {
                return true
            }
        }
        return false
    }

    /// Clones the mailbox address.
    ///
    /// - Returns: The cloned mailbox address.
    public override func copy() -> InternetAddress {
        let copiedRoute = DomainList(route)
        return MailboxAddress(encoding: encoding, name: name, route: copiedRoute, address: addressStorage, at: atIndex)
    }

    /// Gets the mailbox address, optionally encoded according to IDN encoding rules.
    ///
    /// If `idnEncode` is `true`, then the returned mailbox address will be encoded according to the IDN encoding rules.
    ///
    /// - Parameter idnEncode: `true` if the address should be encoded according to IDN encoding rules; otherwise, `false`.
    /// - Returns: The mailbox address.
    public func getAddress(_ idnEncode: Bool) -> String {
        if idnEncode {
            return MailboxAddress.encodeAddrspec(addressStorage, atIndex: atIndex)
        }
        return addressStorage
    }

    internal override func encode(_ options: FormatOptions, builder: inout String, firstToken: inout Bool, lineLength: inout Int) {
        var routeValue = route.encode(options)
        if !routeValue.isEmpty {
            routeValue += ":"
        }

        let addrspec = getAddress(!options.international)

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

            if (lineLength + routeValue.count + addrspec.count + 3) > options.maxLineLength {
                builder.append(options.newLine)
                builder.append("\t<")
                lineLength = 2
            } else {
                builder.append(" <")
                lineLength += 2
            }

            lineLength += routeValue.count
            builder.append(routeValue)

            lineLength += addrspec.count + 1
            builder.append(addrspec)
            builder.append(">")
        } else if !routeValue.isEmpty {
            if !firstToken && (lineLength + routeValue.count + addrspec.count + 2) > options.maxLineLength {
                builder.append(options.newLine)
                builder.append("\t<")
                lineLength = 2
            } else {
                builder.append("<")
                lineLength += 1
            }

            lineLength += routeValue.count
            builder.append(routeValue)

            lineLength += addrspec.count + 1
            builder.append(addrspec)
            builder.append(">")
        } else {
            if !firstToken && (lineLength + addrspec.count) > options.maxLineLength {
                StringBuilderUtils.lineWrap(&builder, options: options)
                lineLength = 1
            }
            lineLength += addrspec.count
            builder.append(addrspec)
        }
    }

    /// Returns a string representation of the ``MailboxAddress``, optionally encoding it for transport.
    ///
    /// Returns a string containing the formatted mailbox address. If the `encoded`
    /// parameter is `true`, then the mailbox name will be encoded according to the rules defined
    /// in rfc2047, otherwise the name will not be encoded at all and will therefore only be suitable
    /// for display purposes.
    ///
    /// - Parameters:
    ///   - options: The formatting options.
    ///   - encoded: If `true`, the ``MailboxAddress`` will be encoded for transport.
    /// - Returns: A string representing the ``MailboxAddress``.
    public override func formatted(with options: FormatOptions = .default, encoded: Bool = false) -> String {
        if encoded {
            var builder = ""
            var lineLength = 0
            var firstToken = true
            self.encode(options, builder: &builder, firstToken: &firstToken, lineLength: &lineLength)
            return builder
        }

        var routeValue = route.description
        if !routeValue.isEmpty {
            routeValue += ":"
        }

        if let name = name, !name.isEmpty {
            return MimeUtils.quote(name) + " <" + routeValue + addressStorage + ">"
        }

        if !routeValue.isEmpty {
            return "<" + routeValue + addressStorage + ">"
        }

        return addressStorage
    }

    /// Determines whether the specified ``MailboxAddress`` is equal to the current ``MailboxAddress``.
    ///
    /// Compares two mailbox addresses to determine if they are identical or not.
    ///
    /// - Parameter other: The ``InternetAddress`` to compare with the current ``MailboxAddress``.
    /// - Returns: `true` if the specified address is equal to the current ``MailboxAddress``; otherwise, `false`.
    internal override func isEqual(to other: InternetAddress?) -> Bool {
        guard let mailbox = other as? MailboxAddress else {
            return false
        }
        return name == mailbox.name && addressStorage == mailbox.address && route.description == mailbox.route.description
    }

    /// Hashes the essential components of this mailbox address.
    ///
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(addressStorage.lowercased())
    }

    // MARK: Addrspec helpers

    /// Encodes an addrspec token according to IDN encoding rules (internal helper).
    private static func encodeAddrspec(_ addrspec: String, atIndex: Int) -> String {
        guard atIndex != -1 else {
            return addrspec
        }
        if !ParseUtils.isInternational(addrspec, startIndex: atIndex + 1) {
            return addrspec
        }
        let local = String(addrspec.prefix(atIndex))
        let domain = idnMapping.encode(String(addrspec.suffix(addrspec.count - atIndex - 1)))
        return local + "@" + domain
    }

    /// Encodes an addrspec token according to IDN encoding rules.
    ///
    /// Encodes an addrspec token according to IDN encoding rules, converting
    /// internationalized domain names to their ASCII-compatible encoding (Punycode).
    ///
    /// - Parameter addrspec: The addrspec token to encode.
    /// - Returns: The encoded addrspec token.
    public static func encodeAddrspec(_ addrspec: String) -> String {
        guard !addrspec.isEmpty else {
            return addrspec
        }

        let buffer = CharsetUtils.getBytes(addrspec, encoding: .utf8)
        var index = 0
        var parsed: String? = nil
        var at = -1
        if (try? InternetAddress.tryParseAddrspec(buffer, index: &index, endIndex: buffer.count, sentinels: emptySentinels, compliance: .looser, throwOnError: false, addrspec: &parsed, at: &at)) != true {
            return addrspec
        }

        return encodeAddrspec(parsed ?? addrspec, atIndex: at)
    }

    /// Decodes an addrspec token according to IDN decoding rules.
    ///
    /// Decodes an addrspec token according to IDN decoding rules, converting
    /// Punycode-encoded domain names back to their Unicode representation.
    ///
    /// - Parameter addrspec: The addrspec token to decode.
    /// - Returns: The decoded addrspec token.
    public static func decodeAddrspec(_ addrspec: String) -> String {
        guard !addrspec.isEmpty else {
            return addrspec
        }

        let buffer = CharsetUtils.getBytes(addrspec, encoding: .utf8)
        var index = 0
        var parsed: String? = nil
        var at = -1
        if (try? InternetAddress.tryParseAddrspec(buffer, index: &index, endIndex: buffer.count, sentinels: emptySentinels, compliance: .looser, throwOnError: false, addrspec: &parsed, at: &at)) != true {
            return addrspec
        }

        return parsed ?? addrspec
    }

    // MARK: Parsing APIs

    internal static func tryParse(_ options: ParserOptions, _ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool, mailbox: inout MailboxAddress?) throws -> Bool {
        var flags: AddressParserFlags = [.allowMailboxAddress]
        if throwOnError {
            flags.insert(.throwOnError)
        }

        var address: InternetAddress? = nil
        if !(try InternetAddress.tryParse(flags, options, text, index: &index, endIndex: endIndex, groupDepth: 0, address: &address)) {
            mailbox = nil
            return false
        }

        mailbox = address as? MailboxAddress
        return mailbox != nil
    }

    // MARK: - Swift-Idiomatic Parsing Initializers

    /// Parses the given text into a new ``MailboxAddress`` instance.
    ///
    /// Parses a single ``MailboxAddress``. If the address is not a mailbox address or
    /// there is more than a single mailbox address, then parsing will fail.
    ///
    /// Use `try?` for optional behavior: `let mb = try? MailboxAddress(parsing: text)`
    ///
    /// - Parameters:
    ///   - text: The text to parse.
    ///   - options: The parser options to use.
    /// - Throws: ``ParseException`` if the text could not be parsed.
    public convenience init(parsing text: String, options: ParserOptions = .default) throws {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        try self.init(parsing: buffer, options: options)
    }

    /// Parses the given input buffer into a new ``MailboxAddress`` instance.
    ///
    /// Parses a single ``MailboxAddress``. If the address is not a mailbox address or
    /// there is more than a single mailbox address, then parsing will fail.
    ///
    /// Use `try?` for optional behavior: `let mb = try? MailboxAddress(parsing: buffer)`
    ///
    /// - Parameters:
    ///   - buffer: The input buffer to parse.
    ///   - options: The parser options to use.
    /// - Throws: ``ParseException`` if the buffer could not be parsed.
    public convenience init(parsing buffer: [UInt8], options: ParserOptions = .default) throws {
        var mailbox: MailboxAddress? = nil
        var index = 0
        let endIndex = buffer.count
        _ = try Self.tryParse(options, buffer, index: &index, endIndex: endIndex, throwOnError: true, mailbox: &mailbox)

        _ = try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: true)

        if index != endIndex {
            throw ParseException("Unexpected token at offset \(index)", tokenIndex: index, errorIndex: index)
        }

        guard let parsed = mailbox else {
            throw ParseException("Invalid mailbox address.", tokenIndex: 0, errorIndex: index)
        }

        self.init(encoding: parsed.encoding, name: parsed.name, route: parsed.route, address: parsed.address, at: parsed.atIndex)
    }
}
