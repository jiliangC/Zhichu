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
// TextToFlowed.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A text to flowed text converter.
///
/// Wraps text to conform with the flowed text format described in RFC 3676.
/// The Content-Type header for the wrapped output text should be set to
/// `text/plain; format=flowed; delsp=yes`.
public final class TextToFlowed: TextConverter {
    private static let maxLineLength = 78

    /// Initializes a new instance of the ``TextToFlowed`` class.
    ///
    /// Creates a new text to flowed text converter.
    public override init() {
        super.init()
    }

    /// Gets the input format.
    ///
    /// Always returns ``TextFormat/plain`` for this converter.
    public override var inputFormat: TextFormat {
        .plain
    }

    /// Gets the output format.
    ///
    /// Always returns ``TextFormat/flowed`` for this converter.
    public override var outputFormat: TextFormat {
        .flowed
    }

    private static func unquote(_ line: [Character], quoteDepth: inout Int) -> Int {
        var index = 0
        quoteDepth = 0

        if line.isEmpty || line[0] != ">" {
            return 0
        }

        repeat {
            quoteDepth += 1
            index += 1

            if index < line.count, line[index] == " " {
                index += 1
            }
        } while index < line.count && line[index] == ">"

        return index
    }

    private static func startsWithFrom(_ line: [Character], _ index: Int) -> Bool {
        guard index + 5 <= line.count else {
            return false
        }
        return line[index] == "F"
            && line[index + 1] == "r"
            && line[index + 2] == "o"
            && line[index + 3] == "m"
            && line[index + 4] == " "
    }

    private static func getFlowedLine(_ flowed: inout [Character], _ line: [Character], index: inout Int, quoteDepth: Int) -> String {
        flowed.removeAll(keepingCapacity: true)

        if quoteDepth > 0 {
            flowed.append(contentsOf: Array(repeating: Character(">"), count: quoteDepth))
        }

        if quoteDepth > 0 || (index < line.count && line[index] == " ") || startsWithFrom(line, index) {
            flowed.append(" ")
        }

        if flowed.count + (line.count - index) <= maxLineLength {
            flowed.append(contentsOf: line[index..<line.count])
            index = line.count
            return String(flowed)
        }

        while index < line.count && flowed.count + 1 < maxLineLength {
            let nextSpace = line[index..<line.count].firstIndex(of: " ")
            let wordEnd = nextSpace ?? line.count
            let softBreak = nextSpace == nil ? 0 : 2
            var wordLength = wordEnd - index

            if flowed.count + wordLength + softBreak <= maxLineLength {
                flowed.append(contentsOf: line[index..<wordEnd])
                index = wordEnd
            } else if wordLength > maxLineLength - (quoteDepth + 1) {
                wordLength = maxLineLength - (flowed.count + 1)
                if wordLength > 0 {
                    flowed.append(contentsOf: line[index..<(index + wordLength)])
                    index += wordLength
                }
                break
            } else {
                break
            }

            while flowed.count + 1 < maxLineLength, index < line.count, line[index] == " " {
                flowed.append(" ")
                index += 1
            }
        }

        if index < line.count {
            flowed.append(" ")
        }

        return String(flowed)
    }

    private static func trimTrailingSpaces(_ line: String) -> String {
        var endIndex = line.endIndex
        while endIndex > line.startIndex {
            let prevIndex = line.index(before: endIndex)
            if line[prevIndex] == " " {
                endIndex = prevIndex
            } else {
                break
            }
        }
        if endIndex == line.endIndex {
            return line
        }
        return String(line[..<endIndex])
    }

    /// Converts the contents of the reader from the ``inputFormat`` to the ``outputFormat``
    /// and uses the writer to write the resulting text.
    ///
    /// Converts plain text to flowed text by wrapping long lines at word boundaries
    /// while preserving quote levels.
    ///
    /// - Parameters:
    ///   - reader: The text reader providing the plain text input.
    ///   - writer: The text writer to receive the flowed text output.
    public override func convert(_ reader: TextReadable, _ writer: TextWritable) {
        if let header, !header.isEmpty {
            writer.write(header)
        }

        var flowed: [Character] = []
        while let line = reader.readLine() {
            let trimmed = Self.trimTrailingSpaces(line)
            let chars = Array(trimmed)
            var quoteDepth = 0
            let startIndex = Self.unquote(chars, quoteDepth: &quoteDepth)
            var index = startIndex

            repeat {
                let flowedLine = Self.getFlowedLine(&flowed, chars, index: &index, quoteDepth: quoteDepth)
                writer.writeLine(flowedLine)
            } while index < chars.count
        }

        if let footer, !footer.isEmpty {
            writer.write(footer)
        }
    }
}
