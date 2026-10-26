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
// MessageIdList.swift
//
// Ported from MimeKit (C#) to Swift.
//

public enum MessageIdListError: Error, Equatable, Sendable {
    case indexOutOfRange(index: Int, count: Int)
}

public final class MessageIdList: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, CustomStringConvertible {
    public typealias Element = String
    public typealias Index = Int

    private var items: [String] = []

    public init() {}

    public var isReadOnly: Bool { false }

    public var startIndex: Int { items.startIndex }
    public var endIndex: Int { items.endIndex }

    public func index(after i: Int) -> Int { items.index(after: i) }

    public subscript(position: Int) -> String {
        get { items[position] }
        set {
            let normalized = MessageIdList.normalize(newValue)
            if items[position] == normalized {
                return
            }
            items[position] = normalized
            onChanged()
        }
    }

    public var count: Int { items.count }

    public func add(_ id: String) {
        items.append(MessageIdList.normalize(id))
        onChanged()
    }

    public func addRange(_ ids: [String]) {
        items.append(contentsOf: ids.map { MessageIdList.normalize($0) })
        onChanged()
    }

    public func contains(_ id: String) -> Bool {
        items.contains(id)
    }

    public func copyTo(_ array: inout [String], startingAt index: Int) throws {
        guard index >= 0 && index <= array.count else {
            throw MessageIdListError.indexOutOfRange(index: index, count: array.count)
        }
        array.insert(contentsOf: items, at: index)
    }

    public func indexOf(_ id: String) -> Int {
        items.firstIndex(of: id) ?? -1
    }

    public func insert(_ id: String, at index: Int) throws {
        guard index >= 0 && index <= items.count else {
            throw MessageIdListError.indexOutOfRange(index: index, count: items.count)
        }
        items.insert(MessageIdList.normalize(id), at: index)
        onChanged()
    }

    public func setItem(at index: Int, _ id: String) throws {
        guard index >= 0 && index < items.count else {
            throw MessageIdListError.indexOutOfRange(index: index, count: items.count)
        }
        let normalized = MessageIdList.normalize(id)
        if items[index] == normalized {
            return
        }
        items[index] = normalized
        onChanged()
    }

    @discardableResult
    public func remove(_ id: String) -> Bool {
        guard let index = items.firstIndex(of: id) else { return false }
        items.remove(at: index)
        onChanged()
        return true
    }

    public func remove(at index: Int) throws {
        guard index >= 0 && index < items.count else {
            throw MessageIdListError.indexOutOfRange(index: index, count: items.count)
        }
        items.remove(at: index)
        onChanged()
    }

    public func clear() {
        items.removeAll(keepingCapacity: true)
        onChanged()
    }

    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == String {
        items.replaceSubrange(subrange, with: newElements.map { MessageIdList.normalize($0) })
        onChanged()
    }

    public func copy() -> MessageIdList {
        let copied = MessageIdList()
        copied.items = items
        return copied
    }

    @available(*, deprecated, renamed: "copy()")
    public func clone() -> MessageIdList {
        copy()
    }

    public func toString() -> String {
        var builder = ""
        for (index, item) in items.enumerated() {
            if index > 0 {
                builder.append(" ")
            }
            builder.append("<")
            builder.append(item)
            builder.append(">")
        }
        return builder
    }

    public var description: String {
        toString()
    }

    internal var changed: ((MessageIdList) -> Void)?

    private func onChanged() {
        changed?(self)
    }

    private static func normalize(_ value: String) -> String {
        guard value.count >= 2, value.first == "<", value.last == ">" else {
            return value
        }
        let start = value.index(after: value.startIndex)
        let end = value.index(before: value.endIndex)
        return String(value[start..<end])
    }
}
