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
// HtmlAttributeId.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// HTML attribute identifiers.
///
/// An enumeration of known HTML attribute identifiers used for efficient
/// attribute comparison without string matching.
public enum HtmlAttributeId: String, Sendable {
    /// An unknown HTML attribute identifier.
    case unknown = ""

    /// The "href" attribute.
    case href = "href"

    /// The "src" attribute.
    case src = "src"

    /// The "alt" attribute.
    case alt = "alt"

    /// The "xmlns" attribute.
    case xmlns = "xmlns"

    /// The "http-equiv" attribute.
    case httpEquiv = "http-equiv"

    /// The "content" attribute.
    case content = "content"

    /// The "charset" attribute.
    case charset = "charset"
}

/// Utility methods for ``HtmlAttributeId`` operations.
///
/// Provides methods for converting between attribute names and identifiers.
public enum HtmlAttributeIdUtils {
    private static let nameToId: [String: HtmlAttributeId] = [
        "href": .href,
        "src": .src,
        "alt": .alt,
        "xmlns": .xmlns,
        "http-equiv": .httpEquiv,
        "content": .content,
        "charset": .charset
    ]

    /// Converts the enum value into the equivalent attribute name.
    ///
    /// - Parameter id: The enum value.
    /// - Returns: The attribute name.
    public static func toAttributeName(_ id: HtmlAttributeId) -> String {
        if id == .unknown {
            return ""
        }
        return id.rawValue
    }

    /// Converts the attribute name into the equivalent attribute id.
    ///
    /// - Parameter name: The attribute name.
    /// - Returns: The attribute id.
    public static func toHtmlAttributeId(_ name: String) -> HtmlAttributeId {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unknown
        }
        return nameToId[trimmed.lowercased()] ?? .unknown
    }
}

/// ``HtmlAttributeId`` extension methods.
public extension HtmlAttributeId {
    /// Gets the attribute name for this identifier.
    var attributeName: String {
        HtmlAttributeIdUtils.toAttributeName(self)
    }

    /// Creates an ``HtmlAttributeId`` from an attribute name string.
    ///
    /// - Parameter name: The attribute name.
    /// - Returns: The corresponding attribute identifier, or ``HtmlAttributeId/unknown`` if not recognized.
    static func from(name: String) -> HtmlAttributeId {
        HtmlAttributeIdUtils.toHtmlAttributeId(name)
    }
}
