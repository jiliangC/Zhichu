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
// HeaderList.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Specifies the type of change that occurred to a ``HeaderList``.
public enum HeaderListChangedAction: Sendable {
    /// A header was added to the list.
    case added
    /// A header was removed from the list.
    case removed
    /// A header in the list was changed.
    case changed
    /// The list was cleared.
    case cleared
}

/// A list of ``Header`` objects.
///
/// Represents a collection of MIME or message headers in the order they appear.
///
/// ## Overview
///
/// ``HeaderList`` is used to store the headers of a MIME message or entity.
/// It provides methods for adding, removing, and modifying headers, as well as
/// subscript access by index, header identifier, or field name.
///
/// ## Example
///
/// ```swift
/// let headers = HeaderList()
/// headers.add(.subject, "Hello World")
/// headers.add(.from, "sender@example.com")
///
/// // Access by header identifier
/// if let subject = headers[.subject] {
///     print("Subject: \(subject)")
/// }
///
/// // Access by field name
/// if let from = headers["From"] {
///     print("From: \(from)")
/// }
/// ```
public final class HeaderList: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, CustomStringConvertible {
    public typealias Element = Header
    public typealias Index = Int

    private var headers: [Header]

    /// The parser options used when parsing headers.
    public var options: ParserOptions

    internal var changed: ((HeaderListChangedAction, Header?) -> Void)?

    /// Creates a new empty header list.
    ///
    /// Creates a new ``HeaderList`` with default parser options.
    public init() {
        self.headers = []
        self.options = .default
    }

    /// Creates a new empty header list with the specified parser options.
    ///
    /// - Parameter options: The parser options to use.
    public init(_ options: ParserOptions) {
        self.headers = []
        self.options = options
    }

    /// The starting index of the collection.
    public var startIndex: Int { headers.startIndex }

    /// The ending index of the collection.
    public var endIndex: Int { headers.endIndex }

    /// Returns the index after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    ///
    /// - Returns: The index immediately after `i`.
    public func index(after i: Int) -> Int { headers.index(after: i) }

    /// Accesses the header at the specified position.
    ///
    /// - Parameter position: The index of the header to access.
    ///
    /// - Returns: The header at the specified index.
    public subscript(position: Int) -> Header {
        get { headers[position] }
        set {
            headers[position].changed = nil
            attach(newValue)
            headers[position] = newValue
            onChanged(.changed, header: newValue)
        }
    }

    /// Gets or sets the value of the first header with the specified identifier.
    ///
    /// When getting, returns the value of the first header with the specified
    /// identifier, or `nil` if no such header exists.
    ///
    /// When setting, if the header exists, its value is updated; if a non-nil
    /// value is provided and no header exists, a new header is added; if `nil`
    /// is provided, all headers with the identifier are removed.
    ///
    /// - Parameter id: The header identifier. Must not be ``HeaderId/unknown``.
    ///
    /// - Returns: The value of the first matching header, or `nil`.
    public subscript(_ id: HeaderId) -> String? {
        get {
            headers.first(where: { $0.id == id })?.value
        }
        set {
            guard id != .unknown else {
                return
            }
            if let value = newValue {
                if let index = headers.firstIndex(where: { $0.id == id }) {
                    headers[index].value = value
                } else {
                    add(Header(id, value: value))
                }
            } else {
                removeAll(id)
            }
        }
    }

    /// Gets or sets the value of the first header with the specified field name.
    ///
    /// When getting, returns the value of the first header with the specified
    /// field name (case-insensitive), or `nil` if no such header exists.
    ///
    /// When setting, if the header exists, its value is updated; if a non-nil
    /// value is provided and no header exists, a new header is added; if `nil`
    /// is provided, all headers with the field name are removed.
    ///
    /// - Parameter field: The header field name.
    ///
    /// - Returns: The value of the first matching header, or `nil`.
    public subscript(field: String) -> String? {
        get {
            let key = field.lowercased()
            return headers.first(where: { $0.field.lowercased() == key })?.value
        }
        set {
            if let value = newValue {
                if let index = headers.firstIndex(where: { $0.field.caseInsensitiveCompare(field) == .orderedSame }) {
                    headers[index].value = value
                } else {
                    add(Header(field: field, value: value))
                }
            } else {
                removeAll(field: field)
            }
        }
    }

    /// The number of headers in the list.
    public var count: Int { headers.count }

    /// Adds a header to the end of the list.
    ///
    /// - Parameter header: The header to add.
    public func add(_ header: Header) {
        attach(header)
        headers.append(header)
        onChanged(.added, header: header)
    }

    /// Adds a header with the specified identifier and value.
    ///
    /// Creates a new header with the given identifier and value, then adds it
    /// to the end of the list.
    ///
    /// - Parameters:
    ///   - id: The header identifier.
    ///   - value: The header value.
    ///   - encoding: The character encoding to use. Defaults to UTF-8.
    public func add(_ id: HeaderId, _ value: String, encoding: String.Encoding = .utf8) {
        add(Header(id, value: value, encoding: encoding))
    }

    /// Inserts a header at the specified index.
    ///
    /// - Parameters:
    ///   - header: The header to insert.
    ///   - index: The index at which to insert the header.
    public func insert(_ header: Header, at index: Int) {
        guard index >= 0 && index <= headers.count else {
            return
        }
        attach(header)
        headers.insert(header, at: index)
        onChanged(.added, header: header)
    }

    /// Removes the header at the specified index.
    ///
    /// - Parameter index: The index of the header to remove.
    public func remove(at index: Int) {
        guard index >= 0 && index < headers.count else {
            return
        }
        let removed = headers.remove(at: index)
        removed.changed = nil
        onChanged(.removed, header: removed)
    }

    /// Removes all headers with the specified identifier.
    ///
    /// - Parameter id: The identifier of the headers to remove.
    ///                 Must not be ``HeaderId/unknown``.
    public func removeAll(_ id: HeaderId) {
        guard id != .unknown else {
            return
        }
        var removed: [Header] = []
        headers.removeAll { header in
            if header.id == id {
                removed.append(header)
                return true
            }
            return false
        }
        for header in removed {
            header.changed = nil
            onChanged(.removed, header: header)
        }
    }

    /// Removes all headers with the specified field name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter field: The field name of the headers to remove.
    public func removeAll(field: String) {
        let key = field.lowercased()
        var removed: [Header] = []
        headers.removeAll { header in
            if header.field.lowercased() == key {
                removed.append(header)
                return true
            }
            return false
        }
        for header in removed {
            header.changed = nil
            onChanged(.removed, header: header)
        }
    }

    /// Removes all headers from the list.
    public func clear() {
        for header in headers {
            header.changed = nil
        }
        headers.removeAll(keepingCapacity: true)
        onChanged(.cleared, header: nil)
    }

    /// Replaces the specified subrange of headers with the given collection.
    ///
    /// - Parameters:
    ///   - subrange: The range of headers to replace.
    ///   - newElements: The new headers to insert.
    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == Header {
        for i in subrange {
            headers[i].changed = nil
        }
        let newArray = Array(newElements)
        for header in newArray {
            attach(header)
        }
        headers.replaceSubrange(subrange, with: newArray)
        onChanged(.changed, header: nil)
    }

    /// Checks if the list contains a header with the specified identifier.
    ///
    /// - Parameter id: The header identifier to search for.
    ///
    /// - Returns: `true` if the list contains a header with the identifier;
    ///            otherwise, `false`.
    public func contains(_ id: HeaderId) -> Bool {
        headers.contains(where: { $0.id == id })
    }

    /// Checks if the list contains a header with the specified field name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter field: The field name to search for.
    ///
    /// - Returns: `true` if the list contains a header with the field name;
    ///            otherwise, `false`.
    public func contains(field: String) -> Bool {
        headers.contains(where: { $0.field.caseInsensitiveCompare(field) == .orderedSame })
    }

    /// Gets the first header with the specified identifier.
    ///
    /// - Parameter id: The header identifier to search for.
    ///
    /// - Returns: The first header with the identifier, or `nil` if not found.
    public func tryGetHeader(_ id: HeaderId) -> Header? {
        headers.first(where: { $0.id == id })
    }

    /// Returns a string representation of the header list.
    ///
    /// Formats all headers in the list, separated by newlines.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use. Defaults to ``FormatOptions/default``.
    ///   - encode: If `true`, header values are encoded; otherwise, decoded
    ///             values are used.
    ///
    /// - Returns: A string containing all formatted headers.
    public func toString(_ options: FormatOptions = .default, encode: Bool = true) -> String {
        var builder = ""
        for (index, header) in headers.enumerated() {
            if index > 0 {
                builder.append(options.newLine)
            }
            builder.append(header.toString(options, encode: encode))
        }
        if options.ensureNewLine && !builder.isEmpty {
            builder.append(options.newLine)
        }
        return builder
    }

    /// A textual description of the header list.
    public var description: String {
        toString(.default, encode: false)
    }

    private func attach(_ header: Header) {
        header.changed = { [weak self] header in
            self?.onChanged(.changed, header: header)
        }
    }

    private func onChanged(_ action: HeaderListChangedAction, header: Header?) {
        changed?(action, header)
    }
}
