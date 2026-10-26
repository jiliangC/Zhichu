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
// ValueStringBuilder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A mutable string builder for efficient string construction.
///
/// `ValueStringBuilder` provides efficient string building operations, avoiding
/// the overhead of repeated string concatenation. It is a value type that can
/// be used to incrementally build strings character by character or by appending
/// string segments.
///
/// ## Basic Usage
///
/// ```swift
/// var builder = ValueStringBuilder()
/// builder.append("Hello")
/// builder.append(" ")
/// builder.append("World")
/// let result = builder.asString()  // "Hello World"
/// ```
///
/// ## With Initial Capacity
///
/// For better performance when the approximate size is known:
///
/// ```swift
/// var builder = ValueStringBuilder(initialCapacity: 100)
/// for item in items {
///     builder.append(item)
/// }
/// let result = builder.asString()
/// ```
///
/// ## Reusing the Builder
///
/// Use ``clear()`` to reuse the builder while keeping its capacity:
///
/// ```swift
/// builder.clear()
/// builder.append("New content")
/// ```
public struct ValueStringBuilder: CustomStringConvertible {
    private var buffer: String

    /// Creates an empty string builder.
    public init() {
        buffer = ""
    }

    /// Creates an empty string builder with reserved capacity.
    ///
    /// - Parameter initialCapacity: The initial capacity to reserve.
    ///   Reserving capacity can improve performance when the approximate
    ///   final size is known.
    public init(initialCapacity: Int) {
        buffer = ""
        if initialCapacity > 0 {
            buffer.reserveCapacity(initialCapacity)
        }
    }

    /// The current length of the built string.
    public var length: Int {
        buffer.count
    }

    /// A string representation of the current content (same as ``asString()``).
    public var description: String {
        buffer
    }

    /// Accesses the character at the specified index.
    ///
    /// - Parameter index: The zero-based index of the character.
    /// - Returns: The character at the specified index.
    ///
    /// - Precondition: `index` must be a valid index in the string.
    public subscript(index: Int) -> Character {
        get {
            let strIndex = buffer.index(buffer.startIndex, offsetBy: index)
            return buffer[strIndex]
        }
        set {
            let strIndex = buffer.index(buffer.startIndex, offsetBy: index)
            buffer.replaceSubrange(strIndex...strIndex, with: String(newValue))
        }
    }

    /// Removes all content but keeps the allocated capacity.
    ///
    /// Use this method to reuse the builder for constructing a new string
    /// without reallocating memory.
    public mutating func clear() {
        buffer.removeAll(keepingCapacity: true)
    }

    /// Removes all content and releases the allocated capacity.
    ///
    /// Use this method when the builder is no longer needed and you want
    /// to release memory.
    public mutating func dispose() {
        buffer.removeAll(keepingCapacity: false)
    }

    /// Appends a character to the end of the builder.
    ///
    /// - Parameter character: The character to append.
    public mutating func append(_ character: Character) {
        buffer.append(character)
    }

    /// Appends a string to the end of the builder.
    ///
    /// - Parameter string: The string to append. If `nil` or empty, nothing is appended.
    public mutating func append(_ string: String?) {
        guard let string = string, !string.isEmpty else {
            return
        }
        buffer.append(string)
    }

    /// Appends multiple strings separated by a character.
    ///
    /// - Parameters:
    ///   - separator: The character to insert between values.
    ///   - values: The strings to join and append.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var builder = ValueStringBuilder()
    /// builder.appendJoin(separator: ",", values: ["a", "b", "c"])
    /// // Result: "a,b,c"
    /// ```
    public mutating func appendJoin(separator: Character, values: [String]) {
        for (index, value) in values.enumerated() {
            if index > 0 {
                append(separator)
            }
            append(value)
        }
    }

    /// Inserts a string at the specified index.
    ///
    /// - Parameters:
    ///   - string: The string to insert. If `nil` or empty, nothing is inserted.
    ///   - index: The position at which to insert the string.
    ///
    /// - Precondition: `index` must be >= 0 and <= `length`.
    public mutating func insert(_ string: String?, at index: Int) {
        guard let string = string, !string.isEmpty else {
            return
        }
        // Clamping/Precondition logic
        precondition(index >= 0 && index <= buffer.count, "index out of range")
        let strIndex = buffer.index(buffer.startIndex, offsetBy: index)
        buffer.insert(contentsOf: string, at: strIndex)
    }

    /// Returns the current content as a string without clearing the builder.
    ///
    /// - Returns: The current string content.
    public func asString() -> String {
        buffer
    }

    /// Returns the current content as a string and clears the builder.
    ///
    /// This is useful when you want to extract the result and immediately
    /// start building a new string.
    ///
    /// - Returns: The current string content.
    public mutating func toString() -> String {
        let result = buffer
        clear()
        return result
    }
}
