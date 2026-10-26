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
// ByteArrayBuilder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Specifies how byte comparisons should be performed.
public enum ByteComparison: Sendable {
    /// Perform a case-sensitive byte-by-byte comparison.
    case sensitive

    /// Perform a case-insensitive comparison for ASCII letters.
    ///
    /// ASCII letters (A-Z and a-z) are compared without regard to case.
    /// Non-ASCII bytes are compared exactly.
    case insensitiveAscii
}

/// A mutable builder for constructing byte arrays efficiently.
///
/// `ByteArrayBuilder` provides efficient byte array construction, avoiding
/// the overhead of repeated array concatenation. It is a move-only type
/// (`~Copyable`) for efficient resource management.
///
/// ## Basic Usage
///
/// ```swift
/// var builder = ByteArrayBuilder()
/// builder.append(0x48)  // 'H'
/// builder.append(0x69)  // 'i'
/// let result = builder.toArray()  // [0x48, 0x69]
/// ```
///
/// ## Appending Ranges
///
/// ```swift
/// let data: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
/// var builder = ByteArrayBuilder(initialCapacity: 10)
/// builder.append(data, startIndex: 0, count: data.count)
/// ```
///
/// ## Comparing Content
///
/// ```swift
/// let expected: [UInt8] = [0x48, 0x45, 0x4C, 0x4C, 0x4F]  // "HELLO"
/// if builder.equals(expected[...], comparison: .insensitiveAscii) {
///     // Content matches "hello" case-insensitively
/// }
/// ```
public struct ByteArrayBuilder: ~Copyable {
    private var buffer: [UInt8]

    /// Creates an empty byte array builder.
    ///
    /// - Parameter initialCapacity: The initial capacity to reserve. Defaults to 0.
    ///   Reserving capacity can improve performance when the approximate
    ///   final size is known.
    public init(initialCapacity: Int = 0) {
        buffer = []
        if initialCapacity > 0 {
            buffer.reserveCapacity(initialCapacity)
        }
    }

    /// The current length of the byte array.
    public var length: Int {
        buffer.count
    }

    /// Removes all content but keeps the allocated capacity.
    ///
    /// Use this method to reuse the builder for constructing a new byte array
    /// without reallocating memory.
    public mutating func clear() {
        buffer.removeAll(keepingCapacity: true)
    }

    /// Appends a single byte to the end of the builder.
    ///
    /// - Parameter byte: The byte to append.
    public mutating func append(_ byte: UInt8) {
        buffer.append(byte)
    }

    /// Appends a range of bytes from an array to the builder.
    ///
    /// - Parameters:
    ///   - bytes: The source byte array.
    ///   - startIndex: The starting index in the source array.
    ///   - count: The number of bytes to append.
    ///
    /// - Precondition: `startIndex` must be >= 0.
    /// - Precondition: `count` must be >= 0.
    /// - Precondition: `startIndex + count` must not exceed the array length.
    public mutating func append(_ bytes: [UInt8], startIndex: Int, count: Int) {
        precondition(startIndex >= 0, "startIndex must be >= 0")
        precondition(count >= 0, "count must be >= 0")
        precondition(startIndex + count <= bytes.count, "startIndex + count exceeds buffer length")
        buffer.reserveCapacity(buffer.count + count)
        buffer.append(contentsOf: bytes[startIndex..<(startIndex + count)])
    }

    /// Returns the current content as a byte array.
    ///
    /// - Returns: A copy of the current byte array content.
    public func toArray() -> [UInt8] {
        buffer
    }

    /// Compares the builder content with another byte sequence.
    ///
    /// - Parameters:
    ///   - other: The byte slice to compare against.
    ///   - comparison: The comparison mode to use. Defaults to `.sensitive`.
    /// - Returns: `true` if the contents are equal according to the comparison mode;
    ///   otherwise, `false`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let expected: [UInt8] = [0x48, 0x45, 0x4C, 0x4C, 0x4F]  // "HELLO"
    /// if builder.equals(expected[...], comparison: .insensitiveAscii) {
    ///     // Content matches "hello" case-insensitively
    /// }
    /// ```
    public func equals(_ other: ArraySlice<UInt8>, comparison: ByteComparison = .sensitive) -> Bool {
        if other.count != buffer.count {
            return false
        }

        let otherStart = other.startIndex
        for index in 0..<buffer.count {
            let lhs = buffer[index]
            let rhs = other[otherStart + index]
            if comparison == .insensitiveAscii {
                let lhsNorm = (lhs >= 0x61 && lhs <= 0x7A) ? (lhs - 0x20) : lhs
                let rhsNorm = (rhs >= 0x61 && rhs <= 0x7A) ? (rhs - 0x20) : rhs
                if lhsNorm != rhsNorm {
                    return false
                }
            } else if lhs != rhs {
                return false
            }
        }

        return true
    }

    /// Removes all content and releases the allocated capacity.
    ///
    /// Use this method when the builder is no longer needed and you want
    /// to release memory.
    public mutating func dispose() {
        buffer.removeAll(keepingCapacity: false)
    }
}
