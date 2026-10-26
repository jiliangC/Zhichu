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
// TextConverter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An abstract class for converting text from one format to another.
///
/// An abstract class for converting text from one format to another.
/// Subclasses implement specific text format conversions such as HTML to plain text,
/// plain text to HTML, flowed text to HTML, etc.
open class TextConverter {
    static let urlPatterns: [UrlPattern] = [
        UrlPattern(type: .addrspec, pattern: "@", prefix: "mailto:"),
        UrlPattern(type: .mailto, pattern: "mailto:", prefix: ""),
        UrlPattern(type: .web, pattern: "www.", prefix: "http://"),
        UrlPattern(type: .web, pattern: "ftp.", prefix: "ftp://"),
        UrlPattern(type: .file, pattern: "file://", prefix: ""),
        UrlPattern(type: .web, pattern: "ftp://", prefix: ""),
        UrlPattern(type: .web, pattern: "sftp://", prefix: ""),
        UrlPattern(type: .web, pattern: "http://", prefix: ""),
        UrlPattern(type: .web, pattern: "https://", prefix: ""),
        UrlPattern(type: .web, pattern: "news://", prefix: ""),
        UrlPattern(type: .web, pattern: "nntp://", prefix: ""),
        UrlPattern(type: .web, pattern: "telnet://", prefix: ""),
        UrlPattern(type: .web, pattern: "webcal://", prefix: ""),
        UrlPattern(type: .web, pattern: "callto:", prefix: ""),
        UrlPattern(type: .web, pattern: "h323:", prefix: ""),
        UrlPattern(type: .web, pattern: "sip:", prefix: "")
    ]

    /// Gets or sets whether the encoding of the input is detected from the byte order mark
    /// or determined by the ``inputEncoding`` property.
    ///
    /// If set to `true`, the converter will examine the first few bytes of the input
    /// to detect a byte order mark (BOM) and use the appropriate encoding. If no BOM
    /// is detected, it falls back to the ``inputEncoding`` property.
    public var detectEncodingFromByteOrderMark: Bool = false

    /// Gets or sets the input encoding.
    ///
    /// The encoding used to interpret the input data when converting from ``Data``.
    public var inputEncoding: String.Encoding = .utf8

    /// Gets or sets the output encoding.
    ///
    /// The encoding used when converting to ``Data``.
    public var outputEncoding: String.Encoding = .utf8

    private var inputStreamBufferSizeStorage: Int = 4096
    private var outputStreamBufferSizeStorage: Int = 4096

    /// Gets or sets the size of the input stream buffer.
    ///
    /// The buffer size used when reading from input streams. Must be greater than zero.
    public var inputStreamBufferSize: Int {
        get { inputStreamBufferSizeStorage }
        set {
            guard newValue > 0 else { return }
            inputStreamBufferSizeStorage = newValue
        }
    }

    /// Gets or sets the size of the output stream buffer.
    ///
    /// The buffer size used when writing to output streams. Must be greater than zero.
    public var outputStreamBufferSize: Int {
        get { outputStreamBufferSizeStorage }
        set {
            guard newValue > 0 else { return }
            outputStreamBufferSizeStorage = newValue
        }
    }

    /// Gets or sets the text that will be appended to the end of the output.
    ///
    /// The footer must be set before conversion begins. The format of the footer
    /// depends on the specific converter implementation.
    public var footer: String?

    /// Gets or sets text that will be prepended to the beginning of the output.
    ///
    /// The header must be set before conversion begins. The format of the header
    /// depends on the specific converter implementation.
    public var header: String?

    /// Initializes a new instance of the ``TextConverter`` class.
    public init() {
    }

    /// Gets the input format.
    ///
    /// The text format that this converter accepts as input.
    open var inputFormat: TextFormat {
        fatalError("Override in subclasses")
    }

    /// Gets the output format.
    ///
    /// The text format that this converter produces as output.
    open var outputFormat: TextFormat {
        fatalError("Override in subclasses")
    }

    /// Converts the contents of the reader from the ``inputFormat`` to the ``outputFormat``
    /// and uses the writer to write the resulting text.
    ///
    /// Subclasses must override this method to implement the actual conversion logic.
    ///
    /// - Parameters:
    ///   - reader: The text reader providing the input.
    ///   - writer: The text writer to receive the output.
    open func convert(_ reader: TextReadable, _ writer: TextWritable) {
        fatalError("Override in subclasses")
    }

    /// Converts text from the ``inputFormat`` to the ``outputFormat``.
    ///
    /// - Parameter text: The text to convert.
    /// - Returns: The converted text.
    public func convert(_ text: String) -> String {
        let reader = StringReader(text)
        let writer = StringWriter()
        convert(reader, writer)
        return writer.string
    }

    /// Converts data from the ``inputFormat`` to the ``outputFormat``.
    ///
    /// The input data is decoded using the ``inputEncoding`` (or an encoding detected
    /// from a byte order mark if ``detectEncodingFromByteOrderMark`` is `true`).
    /// The output is encoded using the ``outputEncoding``.
    ///
    /// - Parameter data: The data to convert.
    /// - Returns: The converted data.
    public func convert(_ data: Data) -> Data {
        let (encoding, offset) = resolveInputEncoding(for: data)
        let slice = data.subdata(in: offset..<data.count)
        let text = String(data: slice, encoding: encoding) ?? ""
        let converted = convert(text)
        return converted.data(using: outputEncoding) ?? Data()
    }

    private func resolveInputEncoding(for data: Data) -> (String.Encoding, Int) {
        guard detectEncodingFromByteOrderMark, data.count >= 2 else {
            return (inputEncoding, 0)
        }

        let bytes = [UInt8](data.prefix(4))

        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            return (.utf8, 3)
        }

        if bytes.count >= 4 {
            if bytes[0] == 0xFF, bytes[1] == 0xFE, bytes[2] == 0x00, bytes[3] == 0x00 {
                return (.utf32LittleEndian, 4)
            }
            if bytes[0] == 0x00, bytes[1] == 0x00, bytes[2] == 0xFE, bytes[3] == 0xFF {
                return (.utf32BigEndian, 4)
            }
        }

        if bytes[0] == 0xFF, bytes[1] == 0xFE {
            return (.utf16LittleEndian, 2)
        }
        if bytes[0] == 0xFE, bytes[1] == 0xFF {
            return (.utf16BigEndian, 2)
        }

        return (inputEncoding, 0)
    }
}
