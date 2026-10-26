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
// TextToHtml.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A text to HTML converter.
///
/// Used to convert plain text into HTML, automatically detecting and linking URLs.
public final class TextToHtml: TextConverter {
    private let scanner: UrlScanner

    /// Gets or sets the footer format.
    ///
    /// Specifies whether the ``TextConverter/footer`` property contains plain text
    /// or HTML markup.
    public var footerFormat: HeaderFooterFormat = .text

    /// Gets or sets the header format.
    ///
    /// Specifies whether the ``TextConverter/header`` property contains plain text
    /// or HTML markup.
    public var headerFormat: HeaderFooterFormat = .text

    /// Gets or sets the ``HtmlTagCallback`` method to use for custom filtering of HTML tags and content.
    ///
    /// Allows customization of how HTML tags are rendered during conversion.
    public var htmlTagCallback: HtmlTagCallback?

    /// Gets or sets whether the converter should only output an HTML fragment.
    ///
    /// If `true`, the converter outputs only the body content without the
    /// `<html>` and `<body>` wrapper tags. If `false`, a complete HTML document is produced.
    public var outputHtmlFragment: Bool = false

    /// Initializes a new instance of the ``TextToHtml`` class.
    ///
    /// Creates a new text to HTML converter.
    public override init() {
        scanner = UrlScanner()
        for pattern in TextConverter.urlPatterns {
            scanner.add(pattern)
        }
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
    /// Always returns ``TextFormat/html`` for this converter.
    public override var outputFormat: TextFormat {
        .html
    }

    private final class TextToHtmlTagContext: HtmlTagContext {
        private let attrs: HtmlAttributeCollection
        private var endTag = false

        init(tag: HtmlTagId, attribute: HtmlAttribute) {
            self.attrs = HtmlAttributeCollection([attribute])
            super.init(tag)
        }

        init(tag: HtmlTagId) {
            self.attrs = HtmlAttributeCollection.empty
            super.init(tag)
        }

        override var tagName: String {
            tagId.htmlTagName
        }

        override var attributes: HtmlAttributeCollection {
            attrs
        }

        override var isEmptyElementTag: Bool {
            tagId == .br
        }

        override var isEndTag: Bool {
            endTag
        }

        func setIsEndTag(_ value: Bool) {
            endTag = value
        }
    }

    private static func defaultHtmlTagCallback(_ tagContext: HtmlTagContext, _ htmlWriter: HtmlWriter) {
        tagContext.writeTag(htmlWriter, writeAttributes: true)
    }

    private static func unquote(_ line: String) -> (line: String, quoteDepth: Int) {
        var index = 0
        let chars = Array(line)
        var quoteDepth = 0

        if chars.isEmpty || chars[0] != ">" {
            return (line, 0)
        }

        repeat {
            quoteDepth += 1
            index += 1
            if index < chars.count, chars[index] == " " {
                index += 1
            }
        } while index < chars.count && chars[index] == ">"

        if index >= chars.count {
            return ("", quoteDepth)
        }

        return (String(chars[index..<chars.count]), quoteDepth)
    }

    private static func suppressContent(_ stack: [TextToHtmlTagContext]) -> Bool {
        for ctx in stack.reversed() {
            if ctx.suppressInnerContent {
                return true
            }
        }
        return false
    }

    private func writeText(_ htmlWriter: HtmlWriter, _ text: String) {
        let callback = htmlTagCallback ?? Self.defaultHtmlTagCallback
        let content = Array(text)
        var startIndex = 0
        let endIndex = content.count

        while startIndex < endIndex {
            let count = endIndex - startIndex
            if let match = scanner.scan(content, startIndex: startIndex, count: count) {
                let matchCount = match.endIndex - match.startIndex

                if match.startIndex > startIndex {
                    htmlWriter.writeText(content, startIndex, match.startIndex - startIndex)
                }

                let href = match.prefix + String(content[match.startIndex..<match.endIndex])
                let ctx = TextToHtmlTagContext(tag: .a, attribute: HtmlAttribute(.href, href))
                callback(ctx, htmlWriter)

                if !ctx.suppressInnerContent {
                    htmlWriter.writeText(content, match.startIndex, matchCount)
                }

                if !ctx.deleteEndTag {
                    ctx.setIsEndTag(true)
                    if ctx.invokeCallbackForEndTag {
                        callback(ctx, htmlWriter)
                    } else {
                        ctx.writeTag(htmlWriter)
                    }
                }

                startIndex = match.endIndex
            } else {
                htmlWriter.writeText(content, startIndex, count)
                break
            }
        }
    }

    /// Converts the contents of the reader from the ``inputFormat`` to the ``outputFormat``
    /// and uses the writer to write the resulting text.
    ///
    /// Converts plain text to HTML, handling quote levels, line breaks, and automatically
    /// detecting and linking URLs.
    ///
    /// - Parameters:
    ///   - reader: The text reader providing the plain text input.
    ///   - writer: The text writer to receive the HTML output.
    public override func convert(_ reader: TextReadable, _ writer: TextWritable) {
        if !outputHtmlFragment {
            writer.write("<html><body>")
        }

        if let header, !header.isEmpty {
            if headerFormat == .text {
                let converter = TextToHtml()
                converter.outputHtmlFragment = true
                let headerReader = StringReader(header)
                converter.convert(headerReader, writer)
            } else {
                writer.write(header)
            }
        }

        let htmlWriter = HtmlWriter(writer)
        let callback = htmlTagCallback ?? Self.defaultHtmlTagCallback
        var stack: [TextToHtmlTagContext] = []
        var currentQuoteDepth = 0

        while let rawLine = reader.readLine() {
            let (line, quoteDepth) = Self.unquote(rawLine)

            while currentQuoteDepth < quoteDepth {
                let ctx = TextToHtmlTagContext(tag: .blockQuote)
                callback(ctx, htmlWriter)
                currentQuoteDepth += 1
                stack.append(ctx)
            }

            while quoteDepth < currentQuoteDepth {
                guard let ctx = stack.popLast() else {
                    break
                }

                if !Self.suppressContent(stack) && !ctx.deleteEndTag {
                    ctx.setIsEndTag(true)
                    if ctx.invokeCallbackForEndTag {
                        callback(ctx, htmlWriter)
                    } else {
                        ctx.writeTag(htmlWriter)
                    }
                }

                if ctx.tagId == .blockQuote {
                    currentQuoteDepth -= 1
                }
            }

            if !Self.suppressContent(stack) {
                writeText(htmlWriter, line)
                let ctx = TextToHtmlTagContext(tag: .br)
                callback(ctx, htmlWriter)
            }
        }

        for ctx in stack.reversed() {
            ctx.setIsEndTag(true)
            if ctx.invokeCallbackForEndTag {
                callback(ctx, htmlWriter)
            } else {
                ctx.writeTag(htmlWriter)
            }
        }

        htmlWriter.flush()

        if let footer, !footer.isEmpty {
            if footerFormat == .text {
                let converter = TextToHtml()
                converter.outputHtmlFragment = true
                let footerReader = StringReader(footer)
                converter.convert(footerReader, writer)
            } else {
                writer.write(footer)
            }
        }

        if !outputHtmlFragment {
            writer.write("</body></html>")
        }
    }
}
