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
// HtmlTextPreviewer.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A text previewer for HTML content.
///
/// Generates a plain text preview from HTML content by extracting visible
/// text while ignoring scripts, styles, and other non-visible elements.
public class HtmlTextPreviewer: TextPreviewer {
    /// Initializes a new instance of the ``HtmlTextPreviewer`` class.
    ///
    /// Creates a new previewer for HTML.
    public override init() {
        super.init()
    }

    /// Gets the input format.
    ///
    /// Always returns ``TextFormat/html`` for this previewer.
    public override var inputFormat: TextFormat {
        .html
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

    private static func append(
        to preview: inout String,
        length: Int,
        maximumLength: Int,
        value: String,
        lastWasSpace: Bool
    ) -> (isFull: Bool, newLength: Int, newLastWasSpace: Bool) {
        let chars = Array(value)
        var i = 0
        var currentLength = length
        var lwsp = lastWasSpace

        while i < chars.count && currentLength < maximumLength {
            let c = chars[i]
            if isWhiteSpace(c) {
                if !lwsp {
                    preview.append(" ")
                    currentLength += 1
                    lwsp = true
                }
            } else {
                preview.append(c)
                currentLength += 1
                lwsp = false
            }
            i += 1
        }

        if i < chars.count {
            if !preview.isEmpty {
                preview.removeLast()
                preview.append("\u{2026}")
            }
            return (true, currentLength, false)
        }

        return (false, currentLength, lwsp)
    }

    private class HtmlTagContext {
        let tagId: HtmlTagId
        var listIndex: Int = 0
        var suppressInnerContent: Bool = false

        init(tagId: HtmlTagId) {
            self.tagId = tagId
        }
    }

    private static func pop(_ stack: inout [HtmlTagContext], _ id: HtmlTagId) {
        if let index = stack.lastIndex(where: { $0.tagId == id }) {
            stack.remove(at: index)
        }
    }

    private static func shouldSuppressInnerContent(_ id: HtmlTagId) -> Bool {
        switch id {
        case .ol, .script, .style, .table, .tbody, .thead, .tr, .ul:
            return true
        default:
            return false
        }
    }

    private static func suppressContent(_ stack: [HtmlTagContext]) -> Bool {
        return stack.last?.suppressInnerContent ?? false
    }

    private static func getListItemContext(_ stack: [HtmlTagContext]) -> HtmlTagContext? {
        return stack.last(where: { $0.tagId == .ol || $0.tagId == .ul })
    }

    /// Gets a text preview of a stream of text.
    ///
    /// Parses the HTML content and extracts visible text to generate a preview
    /// string. The preview is limited to ``TextPreviewer/maximumPreviewLength`` characters.
    ///
    /// - Parameter reader: The original text stream containing HTML.
    /// - Returns: A string representing a shortened preview of the original text.
    public override func getPreviewText(_ reader: TextReadable) -> String {
        let tokenizer = HtmlTokenizer(reader)
        
        var preview = ""
        var previewLength = 0
        var stack: [HtmlTagContext] = []
        var prefix = ""
        var body = false
        var full = false
        var lwsp = true

        while !full, let token = tokenizer.readNextToken() {
            switch token.kind {
            case .tag:
                guard let tag = token as? HtmlTagToken else { break }
                if !tag.isEndTag {
                    if body {
                        switch tag.id {
                        case .image:
                            if let attr = tag.attributes.first(where: { $0.id == .alt }), let value = attr.value {
                                let result = Self.append(to: &preview, length: previewLength, maximumLength: maximumPreviewLength, value: prefix + value, lastWasSpace: lwsp)
                                full = result.isFull
                                previewLength = result.newLength
                                lwsp = result.newLastWasSpace
                                prefix = ""
                            }
                        case .li:
                            if let ctx = Self.getListItemContext(stack) {
                                if ctx.tagId == .ol {
                                    ctx.listIndex += 1
                                    let result = Self.append(to: &preview, length: previewLength, maximumLength: maximumPreviewLength, value: " \(ctx.listIndex). ", lastWasSpace: lwsp)
                                    full = result.isFull
                                    previewLength = result.newLength
                                    lwsp = result.newLastWasSpace
                                    prefix = ""
                                } else {
                                    prefix = " "
                                }
                            }
                        case .br, .p:
                            prefix = " "
                        default:
                            break
                        }

                        if !tag.isEmptyElement {
                            let ctx = HtmlTagContext(tagId: tag.id)
                            ctx.suppressInnerContent = Self.shouldSuppressInnerContent(tag.id)
                            stack.append(ctx)
                        }
                    } else if tag.id == .body && !tag.isEmptyElement {
                        body = true
                    }
                } else if tag.id == .body {
                    stack.removeAll()
                    body = false
                } else {
                    Self.pop(&stack, tag.id)
                }
            case .data:
                if body && !Self.suppressContent(stack) {
                    guard let dataToken = token as? HtmlDataToken else { break }
                    let result = Self.append(to: &preview, length: previewLength, maximumLength: maximumPreviewLength, value: prefix + dataToken.data, lastWasSpace: lwsp)
                    full = result.isFull
                    previewLength = result.newLength
                    lwsp = result.newLastWasSpace
                    prefix = ""
                }
            default:
                break
            }
        }

        if lwsp && !preview.isEmpty {
            preview.removeLast()
        }

        return preview
    }
}
