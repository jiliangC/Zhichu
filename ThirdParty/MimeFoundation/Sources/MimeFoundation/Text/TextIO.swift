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
// TextIO.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A protocol for reading text.
///
/// Provides methods for reading characters, lines, and blocks of text.
public protocol TextReadable {
    /// Reads a single line of text.
    ///
    /// - Returns: A line of text, or `nil` if the end has been reached.
    func readLine() -> String?

    /// Reads all remaining text.
    ///
    /// - Returns: All remaining text.
    func readToEnd() -> String

    /// Reads a single character.
    ///
    /// - Returns: A character, or `nil` if the end has been reached.
    func read() -> Character?

    /// Reads a block of characters into a buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read into.
    ///   - index: The starting index in the buffer.
    ///   - count: The maximum number of characters to read.
    /// - Returns: The number of characters actually read.
    func readBlock(_ buffer: inout [Character], index: Int, count: Int) -> Int
}

/// A protocol for writing text.
///
/// Provides methods for writing strings and lines of text.
public protocol TextWritable {
    /// Writes a string.
    ///
    /// - Parameter string: The string to write.
    func write(_ string: String)

    /// Writes a line of text.
    ///
    /// - Parameter string: The string to write, followed by a newline.
    func writeLine(_ string: String)
}

/// A text reader that reads from a string.
///
/// Provides methods for reading characters, lines, and blocks of text from a string.
public final class StringReader: TextReadable {
    private let text: String
    private var index: String.Index

    /// Initializes a new instance of the ``StringReader`` class.
    ///
    /// - Parameter text: The string to read from.
    public init(_ text: String) {
        self.text = text
        self.index = text.startIndex
    }

    /// Reads a single character.
    ///
    /// - Returns: A character, or `nil` if the end has been reached.
    public func read() -> Character? {
        guard index < text.endIndex else {
            return nil
        }
        let char = text[index]
        index = text.index(after: index)
        return char
    }

    /// Reads a block of characters into a buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to read into.
    ///   - index: The starting index in the buffer.
    ///   - count: The maximum number of characters to read.
    /// - Returns: The number of characters actually read.
    public func readBlock(_ buffer: inout [Character], index startIndex: Int, count: Int) -> Int {
        var nread = 0
        while nread < count, index < text.endIndex {
            buffer[startIndex + nread] = text[index]
            index = text.index(after: index)
            nread += 1
        }
        return nread
    }

    /// Reads a single line of text.
    ///
    /// - Returns: A line of text, or `nil` if the end has been reached.
    public func readLine() -> String? {
        guard index < text.endIndex else {
            return nil
        }

        var lineEnd = index
        while lineEnd < text.endIndex {
            let ch = text[lineEnd]
            if ch == "\n" || ch == "\r" {
                break
            }
            lineEnd = text.index(after: lineEnd)
        }

        let line = String(text[index..<lineEnd])

        if lineEnd < text.endIndex {
            let newlineChar = text[lineEnd]
            lineEnd = text.index(after: lineEnd)
            if newlineChar == "\r", lineEnd < text.endIndex, text[lineEnd] == "\n" {
                lineEnd = text.index(after: lineEnd)
            }
        }

        index = lineEnd
        return line
    }

    /// Reads all remaining text.
    ///
    /// - Returns: All remaining text.
    public func readToEnd() -> String {
        guard index < text.endIndex else {
            return ""
        }
        let remaining = String(text[index...])
        index = text.endIndex
        return remaining
    }
}

/// A text writer that writes to a string.
///
/// Provides methods for writing strings and building up a string buffer.
public final class StringWriter: TextWritable {
    private var buffer: String

    /// Initializes a new instance of the ``StringWriter`` class.
    public init() {
        buffer = ""
    }

    /// Writes a string.
    ///
    /// - Parameter string: The string to write.
    public func write(_ string: String) {
        buffer.append(string)
    }

    /// Writes a line of text.
    ///
    /// - Parameter string: The string to write, followed by a newline.
    public func writeLine(_ string: String) {
        buffer.append(string)
        buffer.append("\n")
    }

    /// Gets the accumulated string.
    ///
    /// The string containing all written text.
    public var string: String {
        buffer
    }
}
