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
// HtmlTagContext.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A callback function for customizing HTML tag processing.
///
/// This callback is used by text converters to allow custom filtering and transformation
/// of HTML tags during conversion.
///
/// - Parameters:
///   - tagContext: The HTML tag context providing information about the tag.
///   - htmlWriter: The HTML writer to use for writing the tag.
public typealias HtmlTagCallback = (_ tagContext: HtmlTagContext, _ htmlWriter: HtmlWriter) -> Void

/// An HTML tag context.
///
/// An HTML tag context used with the ``HtmlTagCallback`` delegate to provide information
/// about an HTML tag being processed during text conversion.
open class HtmlTagContext {
    /// Gets the HTML tag identifier.
    public let tagId: HtmlTagId

    /// Gets or sets whether the inner content of the tag should be suppressed.
    ///
    /// When set to `true`, the content between the opening and closing tags will not be written to the output.
    public var suppressInnerContent: Bool = false

    /// Gets or sets whether the end tag should be deleted.
    ///
    /// When set to `true`, the closing tag will not be written to the output.
    public var deleteEndTag: Bool = false

    /// Gets or sets whether the tag should be deleted.
    ///
    /// When set to `true`, neither the opening tag nor the closing tag will be written to the output.
    public var deleteTag: Bool = false

    /// Gets or sets whether the ``HtmlTagCallback`` should be invoked for the end tag.
    ///
    /// When set to `true`, the callback will be invoked when the closing tag is processed.
    public var invokeCallbackForEndTag: Bool = false

    /// Initializes a new instance of the ``HtmlTagContext`` class.
    ///
    /// Creates a new ``HtmlTagContext``.
    ///
    /// - Parameter tagId: The HTML tag identifier.
    public init(_ tagId: HtmlTagId) {
        self.tagId = tagId
    }

    /// Gets the HTML tag name.
    ///
    /// The tag name corresponding to the ``tagId``.
    open var tagName: String {
        tagId.htmlTagName
    }

    /// Gets the HTML tag attributes.
    ///
    /// A collection of attributes associated with the tag.
    open var attributes: HtmlAttributeCollection {
        HtmlAttributeCollection.empty
    }

    /// Gets whether the tag is an empty element.
    ///
    /// Empty elements are self-closing tags like `<br>`, `<img>`, etc.
    open var isEmptyElementTag: Bool {
        tagId.isEmptyElement
    }

    /// Gets whether the tag is an end tag.
    ///
    /// Returns `true` for closing tags like `</div>`.
    open var isEndTag: Bool {
        false
    }

    /// Writes the HTML tag.
    ///
    /// Writes the HTML tag to the given ``HtmlWriter``.
    ///
    /// - Parameter htmlWriter: The HTML writer.
    public func writeTag(_ htmlWriter: HtmlWriter) {
        writeTag(htmlWriter, writeAttributes: false)
    }

    /// Writes the HTML tag.
    ///
    /// Writes the HTML tag to the given ``HtmlWriter``.
    ///
    /// - Parameters:
    ///   - htmlWriter: The HTML writer.
    ///   - writeAttributes: `true` if the ``attributes`` should also be written; otherwise, `false`.
    public func writeTag(_ htmlWriter: HtmlWriter, writeAttributes: Bool) {
        if deleteTag {
            return
        }

        if isEndTag {
            htmlWriter.writeEndTag(tagName)
            return
        }

        if isEmptyElementTag {
            htmlWriter.writeEmptyElementTag(tagName)
        } else {
            htmlWriter.writeStartTag(tagName)
        }

        if writeAttributes {
            for i in 0..<attributes.count {
                htmlWriter.writeAttribute(attributes[i])
            }
        }
    }
}
