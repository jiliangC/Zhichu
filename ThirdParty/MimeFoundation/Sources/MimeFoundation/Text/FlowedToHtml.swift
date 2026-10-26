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
// FlowedToHtml.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A flowed text to HTML converter.
///
/// Used to convert flowed text (as described in RFC 3676) into HTML.
/// The flowed text format is commonly used in email messages to allow
/// text to be reflowed by the recipient's mail client.
public final class FlowedToHtml: TextConverter {
    private let scanner: UrlScanner

    /// Gets or sets whether the trailing space on a wrapped line should be deleted.
    ///
    /// The flowed text format defines a Content-Type parameter called "delsp" which can
    /// have a value of "yes" or "no". If the parameter exists and the value is "yes", then
    /// ``deleteSpace`` should be set to `true`, otherwise ``deleteSpace``
    /// should be set to `false`.
    public var deleteSpace: Bool = false

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

    /// Initializes a new instance of the ``FlowedToHtml`` class.
    ///
    /// Creates a new flowed text to HTML converter.
    public override init() {
        scanner = UrlScanner()
        for pattern in TextConverter.urlPatterns {
            scanner.add(pattern)
        }
        super.init()
    }

    /// Gets the input format.
    ///
    /// Always returns ``TextFormat/flowed`` for this converter.
    public override var inputFormat: TextFormat {
        .flowed
    }

    /// Gets the output format.
    ///
    /// Always returns ``TextFormat/html`` for this converter.
    public override var outputFormat: TextFormat {
        .html
    }

    private final class FlowedToHtmlTagContext: HtmlTagContext {
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

    private struct WriterState {
        var stack: [FlowedToHtmlTagContext] = []
        var currentQuoteDepth: Int = 0
    }

    private static func defaultHtmlTagCallback(_ tagContext: HtmlTagContext, _ htmlWriter: HtmlWriter) {
        tagContext.writeTag(htmlWriter, writeAttributes: true)
    }

    private static func unquote(_ line: [Character]) -> (content: ArraySlice<Character>, quoteDepth: Int) {
        var index = 0
        var quoteDepth = 0

        if line.isEmpty {
            return (line[index...], 0)
        }

        while index < line.count && line[index] == ">" {
            quoteDepth += 1
            index += 1
        }

        if index > 0, index < line.count, line[index] == " " {
            index += 1
        }

        if index >= line.count {
            return (line[line.count..<line.count], quoteDepth)
        }

        return (line[index...], quoteDepth)
    }

    private static func suppressContent(_ stack: [FlowedToHtmlTagContext]) -> Bool {
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
                let ctx = FlowedToHtmlTagContext(tag: .a, attribute: HtmlAttribute(.href, href))
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

    private func writeParagraph(_ htmlWriter: HtmlWriter, state: inout WriterState, paragraph: String, quoteDepth: Int) {
        let callback = htmlTagCallback ?? Self.defaultHtmlTagCallback

        while state.currentQuoteDepth < quoteDepth {
            let ctx = FlowedToHtmlTagContext(tag: .blockQuote)
            callback(ctx, htmlWriter)
            state.currentQuoteDepth += 1
            state.stack.append(ctx)
        }

        while quoteDepth < state.currentQuoteDepth {
            guard let ctx = state.stack.popLast() else {
                break
            }

            if !Self.suppressContent(state.stack) && !ctx.deleteEndTag {
                ctx.setIsEndTag(true)
                if ctx.invokeCallbackForEndTag {
                    callback(ctx, htmlWriter)
                } else {
                    ctx.writeTag(htmlWriter)
                }
            }

            if ctx.tagId == .blockQuote {
                state.currentQuoteDepth -= 1
            }
        }

        if Self.suppressContent(state.stack) {
            return
        }

        let ctx = FlowedToHtmlTagContext(tag: paragraph.isEmpty ? .br : .p)
        callback(ctx, htmlWriter)

        if !paragraph.isEmpty {
            if !ctx.suppressInnerContent {
                writeText(htmlWriter, paragraph)
            }

            if !ctx.deleteEndTag {
                ctx.setIsEndTag(true)
                if ctx.invokeCallbackForEndTag {
                    callback(ctx, htmlWriter)
                } else {
                    ctx.writeTag(htmlWriter)
                }
            }
        }

        if !ctx.deleteTag {
            htmlWriter.writeMarkupText("\n")
        }
    }

    /// Converts the contents of the reader from the ``inputFormat`` to the ``outputFormat``
    /// and uses the writer to write the resulting text.
    ///
    /// Converts flowed text to HTML, handling quote levels, paragraph detection,
    /// and URL auto-linking.
    ///
    /// - Parameters:
    ///   - reader: The text reader providing the flowed text input.
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
        var state = WriterState()
        var paragraph = ""
        var paragraphQuoteDepth = -1

        while let line = reader.readLine() {
            let chars = Array(line)
            var (unquoted, quoteDepth) = Self.unquote(chars)

            if quoteDepth == 0, let first = unquoted.first, first == " " {
                unquoted = unquoted.dropFirst()
            }

            if paragraph.isEmpty {
                paragraphQuoteDepth = quoteDepth
            } else if quoteDepth != paragraphQuoteDepth {
                writeParagraph(htmlWriter, state: &state, paragraph: paragraph, quoteDepth: paragraphQuoteDepth)
                paragraphQuoteDepth = quoteDepth
                paragraph = ""
            }

            if !unquoted.isEmpty {
                paragraph.append(contentsOf: unquoted)
            }

            if unquoted.isEmpty || unquoted.last != " " {
                writeParagraph(htmlWriter, state: &state, paragraph: paragraph, quoteDepth: paragraphQuoteDepth)
                paragraphQuoteDepth = 0
                paragraph = ""
            } else if deleteSpace, !paragraph.isEmpty {
                paragraph.removeLast()
            }
        }

        if !paragraph.isEmpty {
            writeParagraph(htmlWriter, state: &state, paragraph: paragraph, quoteDepth: paragraphQuoteDepth)
        }

        for ctx in state.stack.reversed() {
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
