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
// PlainTextPreviewer.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A text previewer for plain text.
///
/// Generates a preview from plain text by collapsing whitespace and
/// truncating to the maximum preview length.
public class PlainTextPreviewer: TextPreviewer {
    /// Initializes a new instance of the ``PlainTextPreviewer`` class.
    ///
    /// Creates a new previewer for plain text.
    public override init() {
        super.init()
    }

    /// Gets the input format.
    ///
    /// Always returns ``TextFormat/plain`` for this previewer.
    public override var inputFormat: TextFormat {
        .plain
    }

    private static func isWhiteSpace(_ c: Character) -> Bool {
        if c.isWhitespace {
            return true
        }
        for scalar in c.unicodeScalars {
            let v = scalar.value
            if v >= 0x200B && v <= 0x200D {
                return true
            }
        }
        return false
    }

    /// Gets a text preview of a string of text.
    ///
    /// Collapses whitespace and generates a preview string limited to
    /// ``TextPreviewer/maximumPreviewLength`` characters.
    ///
    /// - Parameter text: The original text.
    /// - Returns: A string representing a shortened preview of the original text.
    public override func getPreviewText(_ text: String) -> String {
        if text.isEmpty {
            return ""
        }

        var preview = ""
        preview.reserveCapacity(min(maximumPreviewLength, text.count))
        var lwsp = true
        var count = 0
        let chars = Array(text)
        var i = 0

        while i < chars.count && count < maximumPreviewLength {
            let c = chars[i]
            if Self.isWhiteSpace(c) {
                if !lwsp {
                    preview.append(" ")
                    count += 1
                    lwsp = true
                }
            } else {
                preview.append(c)
                count += 1
                lwsp = false
            }
            i += 1
        }

        if i < chars.count {
            if !preview.isEmpty {
                preview.removeLast()
                preview.append("\u{2026}")
            }
        } else if lwsp && !preview.isEmpty {
            preview.removeLast()
        }

        return preview
    }

    /// Gets a text preview of a stream of text.
    ///
    /// Reads from the stream, collapses whitespace, and generates a preview string
    /// limited to ``TextPreviewer/maximumPreviewLength`` characters.
    ///
    /// - Parameter reader: The original text stream.
    /// - Returns: A string representing a shortened preview of the original text.
    public override func getPreviewText(_ reader: TextReadable) -> String {
        var preview = ""
        preview.reserveCapacity(maximumPreviewLength)
        var lwsp = true
        var count = 0
        var truncated = false

        while let c = reader.read() {
            if Self.isWhiteSpace(c) {
                if !lwsp {
                    if count < maximumPreviewLength {
                        preview.append(" ")
                        count += 1
                        lwsp = true
                    } else {
                        truncated = true
                        break
                    }
                }
            } else {
                if count < maximumPreviewLength {
                    preview.append(c)
                    count += 1
                    lwsp = false
                } else {
                    truncated = true
                    break
                }
            }
        }

        if truncated {
            if !preview.isEmpty {
                preview.removeLast()
                preview.append("\u{2026}")
            }
        } else if lwsp && !preview.isEmpty {
            preview.removeLast()
        }

        return preview
    }
}
