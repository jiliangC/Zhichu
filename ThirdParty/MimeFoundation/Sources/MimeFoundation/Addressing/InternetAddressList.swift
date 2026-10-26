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
// InternetAddressList.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A list of email addresses.
///
/// An ``InternetAddressList`` may contain any number of addresses of any type
/// defined by the original Internet Message specification.
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
public final class InternetAddressList: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, Equatable, Comparable, CustomStringConvertible {
    public typealias Element = InternetAddress
    public typealias Index = Int

    private var list: [InternetAddress]

    /// Initializes a new instance of the ``InternetAddressList`` class.
    ///
    /// Creates a new, empty, ``InternetAddressList``.
    public init() {
        self.list = []
    }

    /// Initializes a new instance of the ``InternetAddressList`` class.
    ///
    /// Creates a new ``InternetAddressList`` containing the supplied addresses.
    ///
    /// - Parameter addresses: An initial list of addresses.
    public init(_ addresses: [InternetAddress]) {
        self.list = []
        self.list.reserveCapacity(addresses.count)
        for address in addresses {
            address.changed = { [weak self] _ in
                self?.onChanged()
            }
            list.append(address)
        }
    }

    /// Initializes a new instance of the ``InternetAddressList`` class.
    ///
    /// Creates a new ``InternetAddressList`` containing the supplied addresses.
    ///
    /// - Parameter addresses: A sequence of addresses.
    public convenience init<S: Sequence>(_ addresses: S) where S.Element == InternetAddress {
        self.init(Array(addresses))
    }

    /// The position of the first element in the list.
    public var startIndex: Int { list.startIndex }

    /// The position one greater than the last valid subscript argument.
    public var endIndex: Int { list.endIndex }

    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int { list.index(after: i) }

    /// Gets or sets the ``InternetAddress`` at the specified index.
    ///
    /// - Parameter position: The index of the address to get or set.
    /// - Returns: The internet address at the specified index.
    public subscript(position: Int) -> InternetAddress {
        get { list[position] }
        set {
            list[position].changed = nil
            newValue.changed = { [weak self] _ in
                self?.onChanged()
            }
            list[position] = newValue
            onChanged()
        }
    }

    /// The number of addresses in the ``InternetAddressList``.
    public var count: Int { list.count }

    /// A value indicating whether the ``InternetAddressList`` is read only.
    ///
    /// An ``InternetAddressList`` is never read-only.
    public var isReadOnly: Bool { false }

    /// Gets the index of the specified address.
    ///
    /// Finds the index of the specified address, if it exists.
    ///
    /// - Parameter address: The address to get the index of.
    /// - Returns: The index of the specified address if found; otherwise `-1`.
    public func indexOf(_ address: InternetAddress) -> Int {
        list.firstIndex(where: { $0 == address }) ?? -1
    }

    /// Inserts an address at the specified index.
    ///
    /// Inserts the address at the specified index in the list.
    ///
    /// - Parameters:
    ///   - address: The address to insert.
    ///   - index: The index to insert the address.
    public func insert(_ address: InternetAddress, at index: Int) {
        guard index >= 0 && index <= list.count else {
            return
        }
        address.changed = { [weak self] _ in
            self?.onChanged()
        }
        list.insert(address, at: index)
        onChanged()
    }

    /// Removes the address at the specified index.
    ///
    /// - Parameter index: The index of the address to remove.
    public func remove(at index: Int) {
        guard index >= 0 && index < list.count else {
            return
        }
        list[index].changed = nil
        list.remove(at: index)
        onChanged()
    }

    /// Adds an address to the ``InternetAddressList``.
    ///
    /// Adds the specified address to the end of the address list.
    ///
    /// - Parameter address: The address to add.
    public func add(_ address: InternetAddress) {
        address.changed = { [weak self] _ in
            self?.onChanged()
        }
        list.append(address)
        onChanged()
    }

    /// Adds a collection of addresses to the ``InternetAddressList``.
    ///
    /// Adds a range of addresses to the end of the address list.
    ///
    /// - Parameter addresses: A collection of addresses.
    public func addRange(_ addresses: [InternetAddress]) {
        for address in addresses {
            add(address)
        }
    }

    /// Checks if the ``InternetAddressList`` contains the specified address.
    ///
    /// Determines whether the address list contains the specified address.
    ///
    /// - Parameter address: The address to check for.
    /// - Returns: `true` if the specified address exists; otherwise, `false`.
    public func contains(_ address: InternetAddress) -> Bool {
        list.contains(where: { $0 == address })
    }

    /// Removes the specified address from the ``InternetAddressList``.
    ///
    /// - Parameter address: The address to remove.
    /// - Returns: `true` if the address was removed; otherwise, `false`.
    @discardableResult
    public func remove(_ address: InternetAddress) -> Bool {
        guard let index = list.firstIndex(where: { $0 == address }) else {
            return false
        }
        remove(at: index)
        return true
    }

    /// Copies all the addresses in the ``InternetAddressList`` to the specified array.
    ///
    /// Copies all the addresses within the ``InternetAddressList`` into the array,
    /// starting at the specified array index.
    ///
    /// - Parameters:
    ///   - array: The array to copy the addresses to.
    ///   - index: The index into the array.
    public func copyTo(_ array: inout [InternetAddress], at index: Int) {
        guard index >= 0 && index <= array.count else {
            return
        }
        array.insert(contentsOf: list, at: index)
    }

    /// Clears the address list.
    ///
    /// Removes all the addresses from the list.
    public func clear() {
        for address in list {
            address.changed = nil
        }
        list.removeAll(keepingCapacity: true)
        onChanged()
    }

    /// Replaces the specified subrange of elements with the given collection.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the collection to replace.
    ///   - newElements: The new elements to add to the collection.
    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == InternetAddress {
        for i in subrange {
            list[i].changed = nil
        }
        let newArray = Array(newElements)
        for address in newArray {
            address.changed = { [weak self] _ in
                self?.onChanged()
            }
        }
        list.replaceSubrange(subrange, with: newArray)
        onChanged()
    }

    /// Recursively gets all the mailboxes contained within the ``InternetAddressList``.
    ///
    /// This API is useful for collecting a flattened list of ``MailboxAddress``
    /// recipients for use with sending via SMTP or for encrypting via S/MIME or PGP/MIME.
    public var mailboxes: [MailboxAddress] {
        var result: [MailboxAddress] = []
        for address in list {
            if let group = address as? GroupAddress {
                result.append(contentsOf: group.members.mailboxes)
            } else if let mailbox = address as? MailboxAddress {
                result.append(mailbox)
            }
        }
        return result
    }

    internal func encode(_ options: FormatOptions, builder: inout String, firstToken: Bool, lineLength: inout Int) {
        for (idx, address) in list.enumerated() {
            if idx > 0 {
                builder.append(", ")
                lineLength += 2
            }
            var first = firstToken && idx == 0
            address.encode(options, builder: &builder, firstToken: &first, lineLength: &lineLength)
        }
    }

    /// Serializes an ``InternetAddressList`` to a string, optionally encoding the list of addresses for transport.
    ///
    /// If `encode` is `true`, each address in the list will be encoded
    /// according to the rules defined in rfc2047.
    ///
    /// If there are multiple addresses in the list, they will be separated by a comma.
    ///
    /// - Parameters:
    ///   - options: The formatting options.
    ///   - encode: If `true`, each ``InternetAddress`` in the list will be encoded.
    /// - Returns: A string representing the ``InternetAddressList``.
    public func toString(_ options: FormatOptions, encode: Bool) -> String {
        if encode {
            var builder = ""
            var lineLength = 0
            let firstToken = true
            self.encode(options, builder: &builder, firstToken: firstToken, lineLength: &lineLength)
            return builder
        }

        var builder = ""
        for (idx, address) in list.enumerated() {
            if idx > 0 {
                builder.append(", ")
            }
            builder.append(address.formatted(with: options, encoded: false))
        }
        return builder
    }

    /// A string representation of the ``InternetAddressList`` suitable for display.
    ///
    /// If there are multiple addresses in the list, they will be separated by a comma.
    public var description: String {
        toString(FormatOptions.default, encode: false)
    }

    /// Determines whether the specified ``InternetAddressList`` is equal to the current ``InternetAddressList``.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side list.
    ///   - rhs: The right-hand side list.
    /// - Returns: `true` if the lists are equal; otherwise, `false`.
    public static func == (lhs: InternetAddressList, rhs: InternetAddressList) -> Bool {
        if lhs.list.count != rhs.list.count {
            return false
        }
        for (a, b) in zip(lhs.list, rhs.list) {
            if a != b {
                return false
            }
        }
        return true
    }

    /// Compares two internet address lists for the purpose of sorting.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side list.
    ///   - rhs: The right-hand side list.
    /// - Returns: `true` if `lhs` should be ordered before `rhs`; otherwise, `false`.
    public static func < (lhs: InternetAddressList, rhs: InternetAddressList) -> Bool {
        let minCount = Swift.min(lhs.list.count, rhs.list.count)
        for i in 0..<minCount {
            if lhs.list[i] == rhs.list[i] {
                continue
            }
            return lhs.list[i] < rhs.list[i]
        }
        return lhs.list.count < rhs.list.count
    }

    internal var changed: ((InternetAddressList) -> Void)?

    /// Raises the internal changed event.
    private func onChanged() {
        changed?(self)
    }

    // MARK: Parsing

    internal static func tryParse(_ flags: AddressParserFlags, _ options: ParserOptions, _ text: [UInt8], index: inout Int, endIndex: Int, isGroup: Bool, groupDepth: Int, addresses: inout InternetAddressList?) -> Bool {
        let throwOnError = flags.contains(.throwOnError)
        var list: [InternetAddress] = []
        addresses = nil

        do {
            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }
        } catch {
            return false
        }

        if index == endIndex {
            return false
        }

        while index < endIndex {
            if isGroup && text[index] == 0x3B {
                break
            }

            var address: InternetAddress? = nil
            do {
                if !(try InternetAddress.tryParse(flags, options, text, index: &index, endIndex: endIndex, groupDepth: groupDepth, address: &address)) {
                    if !flags.contains(.internalFlag) {
                        return false
                    }
                    while index < endIndex && text[index] != 0x2C && (!isGroup || text[index] != 0x3B) {
                        index += 1
                    }
                } else if let address = address {
                    list.append(address)
                }
            } catch {
                return false
            }

            var skippedComma = false
            repeat {
                do {
                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                        return false
                    }
                } catch {
                    return false
                }

                if index >= endIndex {
                    break
                }

                if isGroup && text[index] == 0x3B {
                    break
                }

                if text[index] != 0x2C {
                    if skippedComma {
                        break
                    }
                    if options.addressParserComplianceMode == .strict {
                        return false
                    }
                    break
                }

                skippedComma = true
                index += 1
            } while true
        }

        addresses = InternetAddressList(list)
        return true
    }

    // MARK: - Swift-Idiomatic Parsing Initializers

    /// Parses the given text into a new ``InternetAddressList`` instance.
    ///
    /// Parses a list of addresses from the specified text.
    ///
    /// Use `try?` for optional behavior: `let list = try? InternetAddressList(parsing: text)`
    ///
    /// - Parameters:
    ///   - text: The text to parse.
    ///   - options: The parser options to use.
    /// - Throws: ``ParseException`` if the text could not be parsed.
    public convenience init(parsing text: String, options: ParserOptions = .default) throws {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        try self.init(parsing: buffer, options: options)
    }

    /// Parses the given input buffer into a new ``InternetAddressList`` instance.
    ///
    /// Parses a list of addresses from the specified buffer.
    ///
    /// Use `try?` for optional behavior: `let list = try? InternetAddressList(parsing: buffer)`
    ///
    /// - Parameters:
    ///   - buffer: The input buffer to parse.
    ///   - options: The parser options to use.
    /// - Throws: ``ParseException`` if the buffer could not be parsed.
    public convenience init(parsing buffer: [UInt8], options: ParserOptions = .default) throws {
        var result: InternetAddressList? = nil
        var index = 0
        if !Self.tryParse(.tryParse, options, buffer, index: &index, endIndex: buffer.count,
                          isGroup: false, groupDepth: 0, addresses: &result) {
            throw ParseException("Invalid address list.", tokenIndex: 0, errorIndex: index)
        }
        if let result {
            self.init(Array(result))
        } else {
            self.init()
        }
    }
}
