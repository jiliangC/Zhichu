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
// OptimizedOrdinalIgnoreCaseComparer.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A high-performance case-insensitive string comparer for ASCII strings.
///
/// `OptimizedOrdinalIgnoreCaseComparer` provides fast case-insensitive comparison
/// and hashing for strings, optimized for ASCII content. It performs character-by-character
/// comparison with uppercase conversion only for ASCII letters (a-z), making it
/// suitable for comparing MIME header names, parameter names, and other ASCII-based
/// protocol elements.
///
/// ## Usage
///
/// ```swift
/// let comparer = OptimizedOrdinalIgnoreCaseComparer()
/// comparer.equals("Content-Type", "content-type")  // true
/// comparer.equals("SUBJECT", "subject")            // true
///
/// let hash1 = comparer.getHashCode("Content-Type")
/// let hash2 = comparer.getHashCode("content-type")
/// // hash1 == hash2
/// ```
///
/// ## Performance
///
/// This comparer is optimized for ASCII strings and performs minimal allocations.
/// Non-ASCII characters are compared by their raw code point values without
/// case conversion.
public struct OptimizedOrdinalIgnoreCaseComparer: Sendable {
    /// Creates a new case-insensitive comparer.
    public init() {}

    /// Compares two strings for equality, ignoring ASCII case differences.
    ///
    /// Performs a character-by-character comparison, treating ASCII letters
    /// (a-z and A-Z) as equal regardless of case. Non-ASCII characters must
    /// match exactly.
    ///
    /// - Parameters:
    ///   - lhs: The first string to compare.
    ///   - rhs: The second string to compare.
    /// - Returns: `true` if the strings are equal ignoring ASCII case; `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let comparer = OptimizedOrdinalIgnoreCaseComparer()
    /// comparer.equals("Hello", "HELLO")     // true
    /// comparer.equals("test", "Test")       // true
    /// comparer.equals("test", "test!")      // false
    /// ```
    public func equals(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf16)
        let right = Array(rhs.utf16)

        if left.count != right.count {
            return false
        }

        for index in 0..<left.count {
            if Self.toUpper(left[index]) != Self.toUpper(right[index]) {
                return false
            }
        }

        return true
    }

    /// Computes a case-insensitive hash code for a string.
    ///
    /// Returns the same hash code for strings that differ only in ASCII case.
    /// This allows case-insensitive lookups in hash-based collections.
    ///
    /// - Parameter string: The string to hash.
    /// - Returns: A hash code that is consistent across case variations of
    ///   ASCII letters.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let comparer = OptimizedOrdinalIgnoreCaseComparer()
    /// let hash1 = comparer.getHashCode("Content-Type")
    /// let hash2 = comparer.getHashCode("CONTENT-TYPE")
    /// // hash1 == hash2
    /// ```
    public func getHashCode(_ string: String) -> Int {
        hashCode(string)
    }

    /// Internal hash code computation using a custom hash algorithm.
    private func hashCode(_ string: String) -> Int {
        let units = Array(string.utf16)
        var hash1: UInt32 = 5381
        var hash2: UInt32 = hash1
        var index = 0

        while index < units.count {
            var value = UInt32(Self.toUpper(units[index]))
            hash1 = ((hash1 << 5) &+ hash1) ^ value
            index += 1

            if index >= units.count {
                break
            }

            value = UInt32(Self.toUpper(units[index]))
            hash2 = ((hash2 << 5) &+ hash2) ^ value
            index += 1
        }

        let result = hash1 &+ (hash2 &* 1_566_083_941)
        return Int(bitPattern: UInt(result))
    }

    /// Converts an ASCII lowercase letter to uppercase.
    ///
    /// Only converts ASCII letters (a-z) to their uppercase equivalents.
    /// All other characters (including non-ASCII) are returned unchanged.
    ///
    /// - Parameter codeUnit: The UTF-16 code unit to convert.
    /// - Returns: The uppercase version if the code unit is an ASCII lowercase
    ///   letter; otherwise, the original code unit.
    private static func toUpper(_ codeUnit: UInt16) -> UInt16 {
        if codeUnit >= 0x61 && codeUnit <= 0x7A {
            return codeUnit - 0x20
        }

        return codeUnit
    }
}
