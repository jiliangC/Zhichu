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
// PackedByteArray.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Errors that can occur during packed byte array operations.
public enum PackedByteArrayError: Error, Equatable, Sendable {
    /// The specified index or range is out of bounds.
    ///
    /// - Parameters:
    ///   - index: The starting index that was out of range.
    ///   - count: The size of the destination array.
    ///   - length: The number of bytes to copy.
    case indexOutOfRange(index: Int, count: Int, length: Int)
}

/// A memory-efficient storage for byte sequences with run-length encoding.
///
/// `PackedByteArray` uses run-length encoding to efficiently store sequences
/// of repeated bytes. Each unique byte value and its consecutive count are
/// stored together, making it particularly efficient for data with many
/// repeated values.
///
/// ## Basic Usage
///
/// ```swift
/// let packed = PackedByteArray()
/// packed.add(0x41)  // 'A'
/// packed.add(0x41)  // 'A' again - stored efficiently
/// packed.add(0x42)  // 'B'
///
/// var output = Array(repeating: UInt8(0), count: packed.count)
/// try packed.copy(to: &output, startIndex: 0)
/// // output = [0x41, 0x41, 0x42]
/// ```
///
/// ## Efficiency
///
/// The internal representation uses 16-bit values where:
/// - Lower 8 bits: The byte value
/// - Upper 8 bits: The repetition count (1-255)
///
/// This makes it ideal for MIME parsing where whitespace and other
/// characters often appear in runs.
public final class PackedByteArray {
    private static let initialBufferSize = 64

    private var buffer: [UInt16]
    private var length: Int
    private var cursor: Int

    /// Creates a new empty packed byte array.
    public init() {
        buffer = Array(repeating: 0, count: Self.initialBufferSize)
        length = 0
        cursor = -1
    }

    /// The total number of bytes stored (including repetitions).
    ///
    /// This is the actual byte count, not the number of unique values.
    /// For example, if you add the same byte 10 times, the count is 10.
    public var count: Int {
        length
    }

    /// Removes all bytes from the array.
    ///
    /// After calling this method, ``count`` returns 0 and the array
    /// is empty. The internal buffer capacity is retained for reuse.
    public func clear() {
        cursor = -1
        length = 0
    }

    /// Adds a byte to the end of the array.
    ///
    /// If the byte being added is the same as the last byte added and the
    /// repetition count has not reached the maximum (255), it increments
    /// the count. Otherwise, it creates a new entry.
    ///
    /// - Parameter item: The byte value to add.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let packed = PackedByteArray()
    /// packed.add(0x20)  // space
    /// packed.add(0x20)  // another space - stored efficiently
    /// packed.add(0x20)  // yet another space - still efficient
    /// // Internally uses just one entry with count=3
    /// ```
    public func add(_ item: UInt8) {
        if cursor < 0 || item != UInt8(buffer[cursor] & 0x00FF) || (buffer[cursor] & 0xFF00) == 0xFF00 {
            ensureBufferSize(cursor + 2)
            cursor += 1
            buffer[cursor] = UInt16(1 << 8) | UInt16(item)
        } else {
            buffer[cursor] = buffer[cursor] & 0x00FF | (buffer[cursor] & 0xFF00) + 0x0100
        }

        length += 1
    }

    /// Copies the packed bytes to a destination array.
    ///
    /// Expands the run-length encoded data and writes the actual byte
    /// sequence to the destination array.
    ///
    /// - Parameters:
    ///   - array: The destination byte array to copy into.
    ///   - startIndex: The starting index in the destination array.
    ///
    /// - Throws: ``PackedByteArrayError/indexOutOfRange(index:count:length:)``
    ///   if the destination range is invalid or too small to hold the data.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let packed = PackedByteArray()
    /// packed.add(0x41)
    /// packed.add(0x41)
    /// packed.add(0x42)
    ///
    /// var output = Array(repeating: UInt8(0), count: 3)
    /// try packed.copy(to: &output, startIndex: 0)
    /// // output = [0x41, 0x41, 0x42]
    /// ```
    public func copy(to array: inout [UInt8], startIndex: Int) throws {
        if startIndex < 0 || startIndex + length > array.count {
            throw PackedByteArrayError.indexOutOfRange(index: startIndex, count: array.count, length: length)
        }

        var index = startIndex
        for i in 0...cursor {
            let count = Int((buffer[i] >> 8) & 0x00FF)
            let value = UInt8(buffer[i] & 0x00FF)

            if count > 0 {
                for _ in 0..<count {
                    array[index] = value
                    index += 1
                }
            }
        }
    }

    private func ensureBufferSize(_ size: Int) {
        if buffer.count > size {
            return
        }

        let ideal = (size + 63) & ~63
        var resized = Array(repeating: UInt16(0), count: ideal)
        if cursor >= 0 {
            resized.replaceSubrange(0...(cursor), with: buffer[0...(cursor)])
        }
        buffer = resized
    }
}
