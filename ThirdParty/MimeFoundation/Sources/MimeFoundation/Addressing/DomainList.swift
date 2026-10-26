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
// DomainList.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A domain list.
///
/// Represents a list of domains, such as those that an email was routed through.
public final class DomainList: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, CustomStringConvertible, Equatable {
    public typealias Element = String
    public typealias Index = Int

    private static let domainSentinels: [UInt8] = [0x2C, 0x3A] // ',' ':'

    private var domains: [String]

    /// The position of the first element in the list.
    public var startIndex: Int { domains.startIndex }

    /// The position one greater than the last valid subscript argument.
    public var endIndex: Int { domains.endIndex }

    /// Initializes a new instance of the ``DomainList`` class.
    ///
    /// Creates a new, empty ``DomainList``.
    public init() {
        self.domains = []
    }

    /// Initializes a new instance of the ``DomainList`` class.
    ///
    /// Creates a new ``DomainList`` based on the domains provided.
    ///
    /// - Parameter domains: A domain list.
    public init(_ domains: [String]) {
        self.domains = domains
    }

    /// Initializes a new instance of the ``DomainList`` class.
    ///
    /// Creates a new ``DomainList`` based on the domains provided.
    ///
    /// - Parameter domains: A sequence of domain strings.
    public init<S: Sequence>(_ domains: S) where S.Element == String {
        self.domains = Array(domains)
    }

    /// Gets or sets the domain at the specified index.
    ///
    /// - Parameter position: The index of the domain to get or set.
    /// - Returns: The domain at the specified index.
    public subscript(position: Int) -> String {
        get { domains[position] }
        set {
            domains[position] = newValue
            onChanged()
        }
    }

    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        domains.index(after: i)
    }

    /// The number of domains in the ``DomainList``.
    public var count: Int { domains.count }

    /// A value indicating whether the ``DomainList`` is read only.
    ///
    /// A ``DomainList`` is never read-only.
    public var isReadOnly: Bool { false }

    /// Gets the index of the requested domain, if it exists.
    ///
    /// Finds the index of the specified domain, if it exists.
    ///
    /// - Parameter domain: The domain to find.
    /// - Returns: The index of the requested domain; otherwise `-1`.
    public func indexOf(_ domain: String) -> Int {
        domains.firstIndex(of: domain) ?? -1
    }

    /// Checks if the ``DomainList`` contains the specified domain.
    ///
    /// Determines whether the domain list contains the specified domain.
    ///
    /// - Parameter domain: The domain to check for.
    /// - Returns: `true` if the specified domain is contained; otherwise, `false`.
    public func contains(_ domain: String) -> Bool {
        domains.contains(domain)
    }

    /// Adds a domain.
    ///
    /// Adds the specified domain to the end of the list.
    ///
    /// - Parameter domain: The domain to add.
    public func add(_ domain: String) {
        domains.append(domain)
        onChanged()
    }

    /// Inserts a domain at the specified index.
    ///
    /// Inserts the domain at the specified index in the list.
    ///
    /// - Parameters:
    ///   - domain: The domain to insert.
    ///   - index: The index to insert the domain.
    public func insert(_ domain: String, at index: Int) {
        domains.insert(domain, at: index)
        onChanged()
    }

    /// Removes the domain at the specified index.
    ///
    /// - Parameter index: The index of the domain to remove.
    public func remove(at index: Int) {
        domains.remove(at: index)
        onChanged()
    }

    /// Removes a domain.
    ///
    /// Removes the first instance of the specified domain from the list if it exists.
    ///
    /// - Parameter domain: The domain to remove.
    /// - Returns: `true` if the domain was removed; otherwise, `false`.
    @discardableResult
    public func remove(_ domain: String) -> Bool {
        guard let idx = domains.firstIndex(of: domain) else {
            return false
        }
        domains.remove(at: idx)
        onChanged()
        return true
    }

    /// Clears the domain list.
    ///
    /// Removes all the domains in the list.
    public func clear() {
        domains.removeAll(keepingCapacity: true)
        onChanged()
    }

    /// Replaces the specified subrange of elements with the given collection.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the collection to replace.
    ///   - newElements: The new elements to add to the collection.
    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == String {
        domains.replaceSubrange(subrange, with: newElements)
        onChanged()
    }

    /// Copies all the domains in the ``DomainList`` to an array.
    ///
    /// Copies all the domains within the ``DomainList`` into the array,
    /// starting at the specified array index.
    ///
    /// - Parameters:
    ///   - array: The array to copy the domains to.
    ///   - index: The index into the array.
    public func copyTo(_ array: inout [String], at index: Int) {
        guard index >= 0 && index <= array.count else {
            return
        }
        array.insert(contentsOf: domains, at: index)
    }

    /// A string representation of the list of domains.
    ///
    /// Each non-empty domain string will be prepended by an '@'.
    /// If there are multiple domains in the list, they will be separated by a comma.
    public var description: String {
        toString()
    }

    /// Returns a string representation of the list of domains.
    ///
    /// Each non-empty domain string will be prepended by an '@'.
    /// If there are multiple domains in the list, they will be separated by a comma.
    ///
    /// - Returns: A string representing the ``DomainList``.
    public func toString() -> String {
        var builder = ValueStringBuilder(initialCapacity: 128)
        for domain in domains {
            if domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            if builder.length > 0 {
                builder.append(",")
            }
            builder.append("@")
            builder.append(domain)
        }
        return builder.asString()
    }

    internal func encode(_ options: FormatOptions) -> String {
        var builder = ValueStringBuilder(initialCapacity: 256)
        for domain in domains {
            if domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            if builder.length > 0 {
                builder.append(",")
            }
            builder.append("@")
            if !options.international && ParseUtils.isInternational(domain) {
                let encoded = MailboxAddress.idnMapping.encode(domain)
                builder.append(encoded)
            } else {
                builder.append(domain)
            }
        }
        return builder.asString()
    }

    internal var changed: ((DomainList) -> Void)?

    /// Raises the internal changed event.
    private func onChanged() {
        changed?(self)
    }

    /// Attempts to parse a ``DomainList`` from the text buffer starting at the specified index.
    ///
    /// The index will only be updated if a ``DomainList`` was successfully parsed.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to parse.
    ///   - index: The index to start parsing.
    ///   - endIndex: An index of the end of the input.
    ///   - throwOnError: A flag indicating whether an exception should be thrown on error.
    ///   - route: The parsed ``DomainList``.
    /// - Returns: `true` if a ``DomainList`` was successfully parsed; otherwise, `false`.
    /// - Throws: ``ParseException`` if `throwOnError` is `true` and parsing fails.
    internal static func tryParse(_ buffer: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool, route: inout DomainList?) throws -> Bool {
        var domains: [String] = []
        let startIndex = index
        route = nil

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete domain-list at offset: \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        if buffer[index] != 0x40 {
            if throwOnError {
                throw ParseException("Invalid domain-list at offset: \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        while index < endIndex {
            index += 1 // skip '@'
            if index >= endIndex {
                if throwOnError {
                    throw ParseException("Incomplete domain-list at offset: \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            var domain: String? = nil
            if !(try ParseUtils.tryParseDomain(buffer, index: &index, endIndex: endIndex, sentinels: domainSentinels, throwOnError: throwOnError, domain: &domain)) {
                return false
            }

            if let domainValue = domain {
                domains.append(domainValue)
            }

            while true {
                if !(try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }

                if index >= endIndex || buffer[index] != 0x2C {
                    break
                }
                index += 1
            }

            if !(try ParseUtils.skipCommentsAndWhiteSpace(buffer, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex || buffer[index] != 0x40 {
                break
            }
        }

        route = DomainList(domains)
        return true
    }

    // MARK: - Swift-Idiomatic Parsing Initializers

    /// Parses the given text into a new ``DomainList`` instance.
    ///
    /// Attempts to parse a ``DomainList`` from the supplied text. The index
    /// will only be updated if a ``DomainList`` was successfully parsed.
    ///
    /// Use `try?` for optional behavior: `let dl = try? DomainList(parsing: text)`
    ///
    /// - Parameter text: The text to parse.
    /// - Throws: ``ParseException`` if the text could not be parsed.
    public convenience init(parsing text: String) throws {
        let buffer = CharsetUtils.getBytes(text, encoding: .utf8)
        try self.init(parsing: buffer)
    }

    /// Parses the given input buffer into a new ``DomainList`` instance.
    ///
    /// Attempts to parse a ``DomainList`` from the supplied buffer.
    ///
    /// Use `try?` for optional behavior: `let dl = try? DomainList(parsing: buffer)`
    ///
    /// - Parameter buffer: The input buffer to parse.
    /// - Throws: ``ParseException`` if the buffer could not be parsed.
    public convenience init(parsing buffer: [UInt8]) throws {
        var result: DomainList? = nil
        var index = 0
        _ = try Self.tryParse(buffer, index: &index, endIndex: buffer.count,
                              throwOnError: true, route: &result)
        guard let parsed = result else {
            throw ParseException("Failed to parse domain list.", tokenIndex: 0, errorIndex: index)
        }
        self.init(parsed)
    }

    /// Determines whether two domain lists are equal.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side list.
    ///   - rhs: The right-hand side list.
    /// - Returns: `true` if the lists are equal; otherwise, `false`.
    public static func == (lhs: DomainList, rhs: DomainList) -> Bool {
        lhs.domains == rhs.domains
    }
}
