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
// StringBuilderUtils.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Internal utilities for formatting and folding text in MIME headers.
///
/// `StringBuilderUtils` provides methods for line wrapping and folding long
/// header values according to RFC 2822 rules. These utilities are used when
/// formatting MIME headers to ensure they don't exceed maximum line lengths.
///
/// ## Line Folding
///
/// RFC 2822 requires that header lines be folded at whitespace boundaries when
/// they exceed a certain length (typically 78 or 998 characters). These methods
/// handle the insertion of CRLF (carriage return + line feed) followed by
/// whitespace continuation.
enum StringBuilderUtils {
    /// Inserts a line break into text according to MIME folding rules.
    ///
    /// Adds a line break (CRLF) and continuation whitespace (typically a tab)
    /// to the text. If the text ends with whitespace, the line break is inserted
    /// before it; otherwise, a tab is appended after the line break.
    ///
    /// - Parameters:
    ///   - text: The text string to modify.
    ///   - options: Format options specifying the newline sequence to use.
    static func lineWrap(_ text: inout String, options: FormatOptions) {
        guard !text.isEmpty else {
            return
        }

        if let last = text.last, last.isWhitespace {
            let insertIndex = text.index(before: text.endIndex)
            text.insert(contentsOf: options.newLine, at: insertIndex)
        } else {
            text.append(options.newLine)
            text.append("\t")
        }
    }

    /// Appends tokens to text with automatic line folding.
    ///
    /// Appends a series of tokens to the text, automatically inserting line
    /// breaks when the current line would exceed the maximum length. Whitespace
    /// tokens are preserved and used to separate non-whitespace tokens, but are
    /// discarded when folding occurs.
    ///
    /// - Parameters:
    ///   - text: The text string to append to.
    ///   - options: Format options specifying maximum line length and newline sequence.
    ///   - lineLength: The current line length. Updated as tokens are appended.
    ///   - tokens: The array of token strings to append.
    static func appendTokens(_ text: inout String, options: FormatOptions, lineLength: inout Int, tokens: [String]) {
        var spaces = ""
        for token in tokens {
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                spaces = token
                continue
            }

            if lineLength + spaces.count + token.count > options.maxLineLength {
                text.append(options.newLine)
                spaces = ""
                text.append("\t")
                lineLength = 1
            } else {
                lineLength += spaces.count
                text.append(spaces)
                spaces = ""
            }

            lineLength += token.count
            text.append(token)
        }
    }

    /// Appends a value to text with word-aware line folding.
    ///
    /// Appends a string value to the text, automatically inserting line breaks
    /// to keep lines within the maximum length. The method is word-aware, breaking
    /// only at whitespace boundaries, and handles quoted strings specially to avoid
    /// breaking them mid-quote.
    ///
    /// - Parameters:
    ///   - text: The text string to append to.
    ///   - options: Format options specifying maximum line length and newline sequence.
    ///   - firstToken: Whether this is the first token being appended. Set to `false`
    ///     after the first word is added.
    ///   - value: The string value to append.
    ///   - lineLength: The current line length. Updated as the value is appended.
    ///
    /// ## Quoted String Handling
    ///
    /// The method treats quoted strings (text enclosed in double quotes) as
    /// indivisible units that should not be broken across lines, even if they
    /// exceed the maximum line length.
    static func appendFolded(_ text: inout String, options: FormatOptions, firstToken: inout Bool, value: String, lineLength: inout Int) {
        var wordIndex = value.startIndex

        while wordIndex < value.endIndex {
            var lwspIndex = wordIndex

            if value[lwspIndex] == "\"" {
                lwspIndex = value.index(after: lwspIndex)
                while lwspIndex < value.endIndex && value[lwspIndex] != "\"" {
                    if value[lwspIndex] == "\\" {
                        lwspIndex = value.index(after: lwspIndex)
                        if lwspIndex < value.endIndex {
                            lwspIndex = value.index(after: lwspIndex)
                        }
                    } else {
                        lwspIndex = value.index(after: lwspIndex)
                    }
                }
                if lwspIndex < value.endIndex {
                    lwspIndex = value.index(after: lwspIndex)
                }
            } else {
                while lwspIndex < value.endIndex && !value[lwspIndex].isWhitespace {
                    lwspIndex = value.index(after: lwspIndex)
                }
            }

            let word = value[wordIndex..<lwspIndex]
            let length = word.count
            if !firstToken && lineLength > 1 && (lineLength + length) > options.maxLineLength {
                lineWrap(&text, options: options)
                lineLength = 1
            }

            text.append(contentsOf: word)
            lineLength += length
            firstToken = false

            wordIndex = lwspIndex
            while wordIndex < value.endIndex && value[wordIndex].isWhitespace {
                wordIndex = value.index(after: wordIndex)
            }

            if wordIndex < value.endIndex && wordIndex > lwspIndex {
                text.append(" ")
                lineLength += 1
            }
        }
    }
}
