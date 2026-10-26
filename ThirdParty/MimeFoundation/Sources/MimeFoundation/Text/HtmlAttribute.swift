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
// HtmlAttribute.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// An HTML attribute.
///
/// Represents an HTML attribute with a name and optional value.
public final class HtmlAttribute {
    private var cachedId: HtmlAttributeId?

    /// Gets the name of the attribute.
    public let name: String

    /// Gets the value of the attribute.
    public let value: String?

    /// Initializes a new instance of the ``HtmlAttribute`` class.
    ///
    /// Creates a new HTML attribute with the given id and value.
    ///
    /// - Parameters:
    ///   - id: The attribute identifier. Must not be ``HtmlAttributeId/unknown``.
    ///   - value: The attribute value.
    public init(_ id: HtmlAttributeId, _ value: String?) {
        precondition(id != .unknown, "HtmlAttributeId.unknown is not valid for HtmlAttribute initialization.")
        self.name = id.attributeName
        self.value = value
        self.cachedId = id
    }

    /// Initializes a new instance of the ``HtmlAttribute`` class.
    ///
    /// Creates a new HTML attribute with the given name and value.
    ///
    /// - Parameters:
    ///   - name: The attribute name.
    ///   - value: The attribute value.
    public init(name: String, value: String?) {
        self.name = name
        self.value = value
        self.cachedId = nil
    }

    /// Gets the HTML attribute identifier.
    ///
    /// The identifier is lazily resolved from the name if not already known.
    public var id: HtmlAttributeId {
        if let cachedId {
            return cachedId
        }
        let resolved = HtmlAttributeId.from(name: name)
        cachedId = resolved
        return resolved
    }
}
