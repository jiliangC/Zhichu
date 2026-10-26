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
// HtmlToken.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// An abstract HTML token class.
///
/// Represents a token emitted by the ``HtmlTokenizer``. Subclasses represent
/// specific token types such as data, comments, and tags.
open class HtmlToken {
    /// Gets the kind of HTML token that this object represents.
    public let kind: HtmlTokenKind

    /// Initializes a new instance of the ``HtmlToken`` class.
    ///
    /// - Parameter kind: The kind of token.
    public init(kind: HtmlTokenKind) {
        self.kind = kind
    }
}

/// An HTML token consisting of character data.
///
/// Represents text content within HTML that is not part of a tag or comment.
public final class HtmlDataToken: HtmlToken {
    /// Gets the character data.
    public let data: String

    /// Initializes a new instance of the ``HtmlDataToken`` class.
    ///
    /// - Parameter data: The character data.
    public init(_ data: String) {
        self.data = data
        super.init(kind: .data)
    }
}

/// An HTML comment token.
///
/// Represents an HTML comment like `<!-- comment -->`.
public final class HtmlCommentToken: HtmlToken {
    /// Gets the comment text.
    public let comment: String

    /// Initializes a new instance of the ``HtmlCommentToken`` class.
    ///
    /// - Parameter comment: The comment text.
    public init(_ comment: String) {
        self.comment = comment
        super.init(kind: .comment)
    }
}

/// An HTML tag token.
///
/// Represents an HTML tag, including start tags, end tags, and empty element tags.
public final class HtmlTagToken: HtmlToken {
    /// Gets the tag name.
    public let name: String

    /// Gets the tag attributes.
    public let attributes: HtmlAttributeCollection

    /// Gets whether the tag is an end tag.
    public let isEndTag: Bool

    /// Gets whether the tag is an empty element (self-closing).
    public let isEmptyElement: Bool

    private lazy var cachedId: HtmlTagId = HtmlTagId.from(tagName: name)

    /// Initializes a new instance of the ``HtmlTagToken`` class.
    ///
    /// - Parameters:
    ///   - name: The tag name.
    ///   - attributes: The tag attributes.
    ///   - isEndTag: `true` if this is an end tag; otherwise, `false`.
    ///   - isEmptyElement: `true` if this is an empty element tag; otherwise, `false`.
    public init(name: String, attributes: [HtmlAttribute], isEndTag: Bool, isEmptyElement: Bool) {
        self.name = name
        self.attributes = HtmlAttributeCollection(attributes)
        self.isEndTag = isEndTag
        self.isEmptyElement = isEmptyElement
        super.init(kind: .tag)
    }

    /// Gets the HTML tag identifier.
    public var id: HtmlTagId {
        cachedId
    }
}
