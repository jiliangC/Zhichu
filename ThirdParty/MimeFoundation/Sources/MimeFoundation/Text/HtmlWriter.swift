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
// HtmlWriter.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// An HTML writer.
///
/// An HTML writer provides methods for writing properly formatted HTML content
/// to a text output stream, handling encoding and tag state management.
public final class HtmlWriter {
    private let writer: TextWritable
    private var state: HtmlWriterState = .default
    private var emptyElement = false

    /// Initializes a new instance of the ``HtmlWriter`` class.
    ///
    /// Creates a new HTML writer that writes to the specified text writer.
    ///
    /// - Parameter writer: The output text writer.
    public init(_ writer: TextWritable) {
        self.writer = writer
    }

    /// Flushes any remaining state to the output stream.
    ///
    /// Ensures that any pending tag state is written to the output.
    public func flush() {
        flushWriterState()
    }

    /// Writes a string containing HTML markup directly to the output, without escaping special characters.
    ///
    /// Use this method when you have pre-formatted HTML that should not be escaped.
    ///
    /// - Parameter text: The string containing HTML markup.
    public func writeMarkupText(_ text: String) {
        flushWriterState()
        if !text.isEmpty {
            writer.write(text)
        }
    }

    /// Writes text to the output stream, escaping special characters.
    ///
    /// Special HTML characters such as `<`, `>`, `&`, and `"` are properly escaped.
    ///
    /// - Parameter text: The text to write.
    public func writeText(_ text: String) {
        flushWriterState()
        if !text.isEmpty {
            HtmlUtils.htmlEncode(writer, text)
        }
    }

    /// Writes text to the output stream, escaping special characters.
    ///
    /// Special HTML characters such as `<`, `>`, `&`, and `"` are properly escaped.
    ///
    /// - Parameters:
    ///   - buffer: The text buffer.
    ///   - startIndex: The index of the first character to write.
    ///   - count: The number of characters to write.
    public func writeText(_ buffer: [Character], _ startIndex: Int, _ count: Int) {
        guard count > 0, startIndex >= 0, startIndex + count <= buffer.count else {
            return
        }
        let slice = buffer[startIndex..<(startIndex + count)]
        writeText(String(slice))
    }

    /// Writes the attribute name to the output stream.
    ///
    /// - Parameter name: The attribute name.
    public func writeAttributeName(_ name: String) {
        guard state != .default else {
            return
        }
        writer.write(" ")
        writer.write(name)
        writer.write("=")
        state = .attribute
    }

    /// Writes the attribute name to the output stream.
    ///
    /// - Parameter id: The attribute identifier.
    public func writeAttributeName(_ id: HtmlAttributeId) {
        writeAttributeName(id.attributeName)
    }

    /// Writes the attribute value to the output stream.
    ///
    /// The value is properly encoded for use in an HTML attribute.
    ///
    /// - Parameter value: The attribute value.
    public func writeAttributeValue(_ value: String) {
        guard state == .attribute else {
            return
        }
        HtmlUtils.htmlAttributeEncode(writer, value)
        state = .tag
    }

    /// Writes the attribute to the output stream.
    ///
    /// Writes both the attribute name and value.
    ///
    /// - Parameter attribute: The attribute.
    public func writeAttribute(_ attribute: HtmlAttribute) {
        writeAttributeName(attribute.name)
        if let value = attribute.value {
            writeAttributeValue(value)
        }
    }

    /// Writes an empty element tag.
    ///
    /// Writes a self-closing tag like `<br/>`.
    ///
    /// - Parameter name: The name of the HTML tag.
    public func writeEmptyElementTag(_ name: String) {
        flushWriterState()
        writer.write("<")
        writer.write(name)
        state = .tag
        emptyElement = true
    }

    /// Writes a start tag.
    ///
    /// Writes an opening tag like `<div>`.
    ///
    /// - Parameter name: The name of the HTML tag.
    public func writeStartTag(_ name: String) {
        flushWriterState()
        writer.write("<")
        writer.write(name)
        state = .tag
        emptyElement = false
    }

    /// Writes an end tag.
    ///
    /// Writes a closing tag like `</div>`.
    ///
    /// - Parameter name: The name of the HTML tag.
    public func writeEndTag(_ name: String) {
        flushWriterState()
        writer.write("</")
        writer.write(name)
        writer.write(">")
    }

    /// Writes a token to the output stream.
    ///
    /// Writes a token that was emitted by the ``HtmlTokenizer`` to the output stream.
    ///
    /// - Parameter token: The HTML token.
    public func writeToken(_ token: HtmlToken) {
        flushWriterState()

        switch token.kind {
        case .data:
            if let dataToken = token as? HtmlDataToken {
                writer.write(dataToken.data)
            }
        case .comment:
            if let commentToken = token as? HtmlCommentToken {
                writer.write("<!--")
                writer.write(commentToken.comment)
                writer.write("-->")
            }
        case .tag:
            if let tagToken = token as? HtmlTagToken {
                if tagToken.isEndTag {
                    writeEndTag(tagToken.name)
                } else if tagToken.isEmptyElement || tagToken.id.isEmptyElement {
                    writeEmptyElementTag(tagToken.name)
                    for i in 0..<tagToken.attributes.count {
                        writeAttribute(tagToken.attributes[i])
                    }
                } else {
                    writeStartTag(tagToken.name)
                    for i in 0..<tagToken.attributes.count {
                        writeAttribute(tagToken.attributes[i])
                    }
                }
            }
        }
    }

    private func flushWriterState() {
        if state != .default {
            state = .default
            writer.write(emptyElement ? "/>" : ">")
            emptyElement = false
        }
    }
}
