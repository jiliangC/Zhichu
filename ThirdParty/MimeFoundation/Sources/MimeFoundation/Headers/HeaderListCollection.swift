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
// HeaderListCollection.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with a ``HeaderListCollection``.
public enum HeaderListCollectionError: Error, Sendable {
    /// The specified index is out of the valid range.
    ///
    /// - Parameters:
    ///   - index: The index that was requested.
    ///   - count: The number of elements in the collection.
    case indexOutOfRange(index: Int, count: Int)

    /// The destination array does not have sufficient capacity.
    ///
    /// - Parameters:
    ///   - required: The number of elements required.
    ///   - available: The available capacity in the destination array.
    case insufficientCapacity(required: Int, available: Int)
}

/// A collection of ``HeaderList`` objects.
///
/// Represents a collection of header groups, typically used to store multiple
/// sets of headers for a multipart MIME message.
///
/// ## Overview
///
/// ``HeaderListCollection`` provides methods for adding, removing, and accessing
/// ``HeaderList`` objects. Changes to any contained ``HeaderList`` will trigger
/// change notifications on the collection.
public final class HeaderListCollection: RandomAccessCollection, MutableCollection, ExpressibleByArrayLiteral {
    public typealias Element = HeaderList
    public typealias Index = Int

    private var groups: [HeaderList]

    internal var changed: (() -> Void)?

    /// Creates a new empty header list collection.
    public init() {
        self.groups = []
    }

    /// Creates a new header list collection containing the specified header lists.
    ///
    /// - Parameter groups: An array of ``HeaderList`` objects to include in the collection.
    public init(_ groups: [HeaderList]) {
        self.groups = []
        for group in groups {
            attach(group)
            self.groups.append(group)
        }
    }

    /// Creates a new header list collection from an array literal.
    ///
    /// - Parameter elements: The header lists to include in the collection.
    public convenience init(arrayLiteral elements: HeaderList...) {
        self.init(elements)
    }

    /// The starting index of the collection.
    public var startIndex: Int { groups.startIndex }

    /// The ending index of the collection.
    public var endIndex: Int { groups.endIndex }

    /// Returns the index after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    ///
    /// - Returns: The index immediately after `i`.
    public func index(after i: Int) -> Int {
        groups.index(after: i)
    }

    /// Accesses the header list at the specified position.
    ///
    /// - Parameter position: The index of the header list to access.
    ///
    /// - Returns: The header list at the specified index.
    ///
    /// - Precondition: `position` must be a valid index (0 <= position < count).
    public subscript(position: Int) -> HeaderList {
        get {
            precondition(position >= 0 && position < groups.count, "Index out of range")
            return groups[position]
        }
        set {
            precondition(position >= 0 && position < groups.count, "Index out of range")
            if groups[position] === newValue {
                return
            }
            detach(groups[position])
            attach(newValue)
            groups[position] = newValue
            onChanged()
        }
    }

    /// The number of header lists in the collection.
    public var count: Int { groups.count }

    /// A Boolean value indicating whether the collection is read-only.
    ///
    /// This property always returns `false` for ``HeaderListCollection``.
    public var isReadOnly: Bool { false }

    /// Gets the header list at the specified index, with validation.
    ///
    /// - Parameter index: The index of the header list to retrieve.
    ///
    /// - Returns: The header list at the specified index.
    ///
    /// - Throws: ``HeaderListCollectionError/indexOutOfRange(index:count:)``
    ///           if the index is out of range.
    public func group(at index: Int) throws -> HeaderList {
        guard index >= 0 && index < groups.count else {
            throw HeaderListCollectionError.indexOutOfRange(index: index, count: groups.count)
        }
        return groups[index]
    }

    /// Replaces the header list at the specified index.
    ///
    /// - Parameters:
    ///   - index: The index of the header list to replace.
    ///   - group: The new header list.
    ///
    /// - Throws: ``HeaderListCollectionError/indexOutOfRange(index:count:)``
    ///           if the index is out of range.
    public func replaceGroup(at index: Int, with group: HeaderList) throws {
        guard index >= 0 && index < groups.count else {
            throw HeaderListCollectionError.indexOutOfRange(index: index, count: groups.count)
        }
        if groups[index] === group {
            return
        }
        detach(groups[index])
        attach(group)
        groups[index] = group
        onChanged()
    }

    /// Adds a header list to the end of the collection.
    ///
    /// - Parameter group: The header list to add.
    public func add(_ group: HeaderList) {
        attach(group)
        groups.append(group)
        onChanged()
    }

    /// Removes all header lists from the collection.
    public func clear() {
        for group in groups {
            detach(group)
        }
        groups.removeAll(keepingCapacity: true)
        onChanged()
    }

    /// Checks if the collection contains the specified header list.
    ///
    /// Uses identity comparison (===) rather than equality comparison.
    ///
    /// - Parameter group: The header list to search for.
    ///
    /// - Returns: `true` if the collection contains the header list;
    ///            otherwise, `false`.
    public func contains(_ group: HeaderList) -> Bool {
        groups.contains { $0 === group }
    }

    /// Copies the header lists to an array, starting at the specified index.
    ///
    /// - Parameters:
    ///   - array: The destination array.
    ///   - arrayIndex: The starting index in the destination array.
    ///
    /// - Throws: ``HeaderListCollectionError/indexOutOfRange(index:count:)``
    ///           if `arrayIndex` is negative.
    /// - Throws: ``HeaderListCollectionError/insufficientCapacity(required:available:)``
    ///           if the destination array does not have enough capacity.
    public func copyTo(_ array: inout [HeaderList], startingAt arrayIndex: Int) throws {
        guard arrayIndex >= 0 else {
            throw HeaderListCollectionError.indexOutOfRange(index: arrayIndex, count: array.count)
        }
        guard arrayIndex + groups.count <= array.count else {
            throw HeaderListCollectionError.insufficientCapacity(required: arrayIndex + groups.count, available: array.count)
        }
        for (offset, group) in groups.enumerated() {
            array[arrayIndex + offset] = group
        }
    }

    /// Removes the first occurrence of the specified header list from the collection.
    ///
    /// Uses identity comparison (===) rather than equality comparison.
    ///
    /// - Parameter group: The header list to remove.
    ///
    /// - Returns: `true` if the header list was found and removed;
    ///            otherwise, `false`.
    @discardableResult
    public func remove(_ group: HeaderList) -> Bool {
        guard let index = groups.firstIndex(where: { $0 === group }) else {
            return false
        }
        detach(groups[index])
        groups.remove(at: index)
        onChanged()
        return true
    }

    private func attach(_ group: HeaderList) {
        group.changed = { [weak self] _, _ in
            self?.onChanged()
        }
    }

    private func detach(_ group: HeaderList) {
        group.changed = nil
    }

    private func onChanged() {
        changed?()
    }
}
