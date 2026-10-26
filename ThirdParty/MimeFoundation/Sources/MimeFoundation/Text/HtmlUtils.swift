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
// HtmlUtils.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A collection of HTML-related utility methods.
///
/// Provides methods for encoding HTML text and attributes to ensure proper
/// escaping of special characters.
public enum HtmlUtils {
    /// Encodes HTML text.
    ///
    /// Encodes special HTML characters such as `<`, `>`, `&`, and `"` into their
    /// corresponding HTML entities.
    ///
    /// - Parameter data: The text to encode.
    /// - Returns: The HTML-encoded string.
    public static func htmlEncode(_ data: String) -> String {
        let writer = StringWriter()
        htmlEncode(writer, data)
        return writer.string
    }

    /// Encodes HTML text to an output writer.
    ///
    /// Encodes special HTML characters such as `<`, `>`, `&`, and `"` into their
    /// corresponding HTML entities and writes the result to the output.
    ///
    /// - Parameters:
    ///   - output: The output writer.
    ///   - data: The text to encode.
    public static func htmlEncode(_ output: TextWritable, _ data: String) {
        guard !data.isEmpty else {
            return
        }

        var result = ""
        result.reserveCapacity(data.count)

        for scalar in data.unicodeScalars {
            let value = scalar.value
            switch value {
            case 9, 10, 12, 13:
                result.unicodeScalars.append(scalar)
            case 39:
                result.append("&#39;")
            case 34:
                result.append("&quot;")
            case 38:
                result.append("&amp;")
            case 60:
                result.append("&lt;")
            case 62:
                result.append("&gt;")
            default:
                if value < 32 || (value >= 127 && value < 160) {
                    break
                }
                if value >= 160 {
                    result.append("&#\(value);")
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }

        output.write(result)
    }

    /// Encodes an HTML attribute value.
    ///
    /// Encodes an HTML attribute value, properly escaping special characters
    /// and wrapping the result in the specified quote character.
    ///
    /// - Parameters:
    ///   - value: The attribute value to encode.
    ///   - quote: The character to use for quoting the attribute value.
    /// - Returns: The HTML-encoded attribute value with quotes.
    public static func htmlAttributeEncode(_ value: String, quote: Character = "\"") -> String {
        let writer = StringWriter()
        htmlAttributeEncode(writer, value, quote: quote)
        return writer.string
    }

    /// Encodes an HTML attribute value to an output writer.
    ///
    /// Encodes an HTML attribute value, properly escaping special characters
    /// and wrapping the result in the specified quote character, then writes
    /// the result to the output.
    ///
    /// - Parameters:
    ///   - output: The output writer.
    ///   - value: The attribute value to encode.
    ///   - quote: The character to use for quoting the attribute value.
    public static func htmlAttributeEncode(_ output: TextWritable, _ value: String, quote: Character = "\"") {
        var result = ""
        result.append(quote)

        for scalar in value.unicodeScalars {
            let v = scalar.value
            switch v {
            case 9, 10, 12, 13:
                result.unicodeScalars.append(scalar)
            case 39:
                if quote == "'" {
                    result.append("&#39;")
                } else {
                    result.append("'")
                }
            case 34:
                if quote == "\"" {
                    result.append("&quot;")
                } else {
                    result.append("\"")
                }
            case 38:
                result.append("&amp;")
            case 60:
                result.append("&lt;")
            case 62:
                result.append("&gt;")
            default:
                if v < 32 || (v >= 127 && v < 160) {
                    break
                }
                if v >= 160 {
                    result.append("&#\(v);")
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }

        result.append(quote)
        output.write(result)
    }
}
