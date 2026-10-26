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
// HtmlAttributeCollection.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A readonly collection of HTML attributes.
///
/// A collection of ``HtmlAttribute`` objects that provides indexed
/// and keyed access to HTML tag attributes.
public final class HtmlAttributeCollection: Sequence {
    /// An empty attribute collection.
    public static var empty: HtmlAttributeCollection {
        HtmlAttributeCollection()
    }

    private var attributes: [HtmlAttribute]

    /// Initializes a new instance of the ``HtmlAttributeCollection`` class.
    ///
    /// Creates a new collection with the specified attributes.
    ///
    /// - Parameter attributes: A collection of attributes.
    public init(_ attributes: [HtmlAttribute] = []) {
        self.attributes = attributes
    }

    /// Gets the number of attributes in the collection.
    public var count: Int {
        attributes.count
    }

    /// Gets the ``HtmlAttribute`` at the specified index.
    ///
    /// - Parameter index: The index.
    /// - Returns: The HTML attribute at the specified index.
    public subscript(index: Int) -> HtmlAttribute {
        attributes[index]
    }

    /// Adds an attribute to the collection.
    ///
    /// - Parameter attribute: The attribute to add.
    public func add(_ attribute: HtmlAttribute) {
        attributes.append(attribute)
    }

    /// Gets an iterator for the attribute collection.
    ///
    /// - Returns: The iterator.
    public func makeIterator() -> IndexingIterator<[HtmlAttribute]> {
        attributes.makeIterator()
    }

    /// Checks if an attribute exists in the collection.
    ///
    /// - Parameter id: The attribute identifier.
    /// - Returns: `true` if the attribute exists within the collection; otherwise, `false`.
    public func contains(_ id: HtmlAttributeId) -> Bool {
        attributes.contains { $0.id == id }
    }

    /// Gets the index of a desired attribute.
    ///
    /// - Parameter id: The attribute identifier.
    /// - Returns: The index of the attribute if found; otherwise, `nil`.
    public func indexOf(_ id: HtmlAttributeId) -> Int? {
        attributes.firstIndex { $0.id == id }
    }

    /// Gets an attribute from the collection if it exists.
    ///
    /// - Parameter id: The id of the attribute.
    /// - Returns: The attribute if found; otherwise, `nil`.
    public func tryGetValue(_ id: HtmlAttributeId) -> HtmlAttribute? {
        attributes.first { $0.id == id }
    }

    /// Gets an attribute from the collection if it exists.
    ///
    /// - Parameter name: The name of the attribute.
    /// - Returns: The attribute if found; otherwise, `nil`.
    public func tryGetValue(_ name: String) -> HtmlAttribute? {
        attributes.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
