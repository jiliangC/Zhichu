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
// TextPreviewer.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An abstract class for generating a text preview of a message.
///
/// An abstract class for generating a text preview of a message. Subclasses
/// implement specific text format handling such as plain text or HTML.
open class TextPreviewer {
    private var _maximumPreviewLength: Int = 230

    /// Initializes a new instance of the ``TextPreviewer`` class.
    public init() {
    }

    /// Gets the input format.
    ///
    /// The text format that this previewer accepts as input.
    open var inputFormat: TextFormat {
        fatalError("Override in subclasses")
    }

    /// Gets or sets the maximum text preview length.
    ///
    /// The default value is `230` which is what the GMail web API seems to use.
    /// Valid values range from 1 to 1024.
    public var maximumPreviewLength: Int {
        get { _maximumPreviewLength }
        set {
            guard newValue >= 1 && newValue <= 1024 else {
                return
            }
            _maximumPreviewLength = newValue
        }
    }

    /// Creates a text previewer for the specified format.
    ///
    /// - Parameter format: The text format.
    /// - Returns: A text previewer appropriate for the format.
    static func create(for format: TextFormat) -> TextPreviewer {
        switch format {
        case .html:
            return HtmlTextPreviewer()
        default:
            return PlainTextPreviewer()
        }
    }

    /// Gets a text preview of the text part.
    ///
    /// Automatically determines the appropriate previewer based on the text part's format
    /// and generates a preview string.
    ///
    /// - Parameter body: The text part.
    /// - Returns: A string representing a shortened preview of the original text.
    public static func getPreviewText(for body: TextPart) -> String {
        guard let content = body.content else {
            return ""
        }

        let charset = body.contentType.charset
        var encoding: String.Encoding? = nil
        if let charset = charset {
            encoding = CharsetUtils.getEncoding(charset)
        }

        // MimeKit reads up to 16KB to detect BOM and decode.
        // For simplicity, we'll use a similar approach if possible.
        let memory = MemoryStream()
        _ = try? content.decodeTo(memory)
        let data = memory.toByteArray()
        
        if data.isEmpty {
            return ""
        }

        let actualEncoding = encoding ?? .utf8 // Should probably use BOM detection here if encoding is nil

        let text = String(data: Data(data), encoding: actualEncoding) ?? ""
        let previewer = create(for: body.format)
        return previewer.getPreviewText(text)
    }

    /// Gets a text preview of a string of text.
    ///
    /// Generates a shortened preview of the original text, limited to
    /// ``maximumPreviewLength`` characters.
    ///
    /// - Parameter text: The original text.
    /// - Returns: A string representing a shortened preview of the original text.
    open func getPreviewText(_ text: String) -> String {
        let reader = StringReader(text)
        return getPreviewText(reader)
    }

    /// Gets a text preview of a stream of text.
    ///
    /// Subclasses must override this method to implement format-specific preview generation.
    ///
    /// - Parameter reader: The original text stream.
    /// - Returns: A string representing a shortened preview of the original text.
    open func getPreviewText(_ reader: TextReadable) -> String {
        fatalError("Override in subclasses")
    }
}
