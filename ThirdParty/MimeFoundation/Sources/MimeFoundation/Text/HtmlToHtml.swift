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
// HtmlToHtml.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// An HTML to HTML converter.
///
/// Used to convert HTML into HTML with optional filtering and transformation.
public final class HtmlToHtml: TextConverter {
    /// Gets or sets whether the converter should remove HTML comments from the output.
    ///
    /// When set to `true`, HTML comments will be removed from the output.
    public var filterComments: Bool = false

    /// Gets or sets whether executable scripts should be stripped from the output.
    ///
    /// When set to `true`, `<script>` tags and their content will be removed from the output.
    public var filterHtml: Bool = false

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

    /// Initializes a new instance of the ``HtmlToHtml`` class.
    ///
    /// Creates a new HTML to HTML converter.
    public override init() {
        super.init()
    }

    /// Gets the input format.
    ///
    /// Always returns ``TextFormat/html`` for this converter.
    public override var inputFormat: TextFormat {
        .html
    }

    /// Gets the output format.
    ///
    /// Always returns ``TextFormat/html`` for this converter.
    public override var outputFormat: TextFormat {
        .html
    }

    private final class HtmlToHtmlTagContext: HtmlTagContext {
        private let tag: HtmlTagToken

        init(_ tag: HtmlTagToken) {
            self.tag = tag
            super.init(tag.id)
        }

        override var tagName: String {
            tag.name
        }

        override var attributes: HtmlAttributeCollection {
            tag.attributes
        }

        override var isEmptyElementTag: Bool {
            tag.isEmptyElement || tag.id.isEmptyElement
        }

        override var isEndTag: Bool {
            tag.isEndTag
        }
    }

    private static func defaultHtmlTagCallback(_ tagContext: HtmlTagContext, _ htmlWriter: HtmlWriter) {
        tagContext.writeTag(htmlWriter, writeAttributes: true)
    }

    private static func suppressContent(_ stack: [HtmlToHtmlTagContext]) -> Bool {
        for ctx in stack.reversed() {
            if ctx.suppressInnerContent {
                return true
            }
        }
        return false
    }

    private static func pop(_ stack: inout [HtmlToHtmlTagContext], _ name: String) -> HtmlToHtmlTagContext? {
        guard !stack.isEmpty else {
            return nil
        }
        for i in stride(from: stack.count - 1, through: 0, by: -1) {
            if stack[i].tagName.compare(name, options: .caseInsensitive) == .orderedSame {
                return stack.remove(at: i)
            }
        }
        return nil
    }

    /// Converts the contents of the reader from the ``inputFormat`` to the ``outputFormat``
    /// and uses the writer to write the resulting text.
    ///
    /// Converts HTML to HTML, optionally filtering comments and scripts based on
    /// the ``filterComments`` and ``filterHtml`` properties.
    ///
    /// - Parameters:
    ///   - reader: The text reader providing the HTML input.
    ///   - writer: The text writer to receive the HTML output.
    public override func convert(_ reader: TextReadable, _ writer: TextWritable) {
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
        var stack: [HtmlToHtmlTagContext] = []
        let tokenizer = HtmlTokenizer(reader)
        tokenizer.decodeCharacterReferences = false

        while let token = tokenizer.readNextToken() {
            switch token.kind {
            case .comment:
                if !filterComments, !Self.suppressContent(stack) {
                    htmlWriter.writeToken(token)
                }
            case .tag:
                guard let tagToken = token as? HtmlTagToken else {
                    break
                }

                if !tagToken.isEndTag {
                    if !tagToken.isEmptyElement {
                        let ctx = HtmlToHtmlTagContext(tagToken)
                        if filterHtml, ctx.tagId == .script {
                            ctx.suppressInnerContent = true
                            ctx.deleteEndTag = true
                            ctx.deleteTag = true
                        } else if !Self.suppressContent(stack) {
                            callback(ctx, htmlWriter)
                        }
                        stack.append(ctx)
                    } else if !Self.suppressContent(stack) {
                        let ctx = HtmlToHtmlTagContext(tagToken)
                        if !filterHtml || ctx.tagId != .script {
                            callback(ctx, htmlWriter)
                        }
                    }
                } else {
                    if let ctx = Self.pop(&stack, tagToken.name) {
                        if !Self.suppressContent(stack) {
                            if ctx.invokeCallbackForEndTag {
                                let endCtx = HtmlToHtmlTagContext(tagToken)
                                endCtx.invokeCallbackForEndTag = ctx.invokeCallbackForEndTag
                                endCtx.suppressInnerContent = ctx.suppressInnerContent
                                endCtx.deleteEndTag = ctx.deleteEndTag
                                endCtx.deleteTag = ctx.deleteTag
                                callback(endCtx, htmlWriter)
                            } else if !ctx.deleteEndTag {
                                htmlWriter.writeEndTag(tagToken.name)
                            }
                        }
                    } else if !Self.suppressContent(stack) {
                        let ctx = HtmlToHtmlTagContext(tagToken)
                        callback(ctx, htmlWriter)
                    }
                }
            case .data:
                if !Self.suppressContent(stack) {
                    htmlWriter.writeToken(token)
                }
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
    }
}
