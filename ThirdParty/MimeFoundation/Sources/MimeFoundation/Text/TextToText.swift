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
// TextToText.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A text to text converter.
///
/// A pass-through converter that copies plain text from input to output,
/// optionally adding header and footer content.
public final class TextToText: TextConverter {
    /// Initializes a new instance of the ``TextToText`` class.
    ///
    /// Creates a new text to text converter.
    public override init() {
        super.init()
    }

    /// Gets the input format.
    ///
    /// Always returns ``TextFormat/plain`` for this converter.
    public override var inputFormat: TextFormat {
        .plain
    }

    /// Gets the output format.
    ///
    /// Always returns ``TextFormat/plain`` for this converter.
    public override var outputFormat: TextFormat {
        .plain
    }

    /// Converts the contents of the reader from the ``inputFormat`` to the ``outputFormat``
    /// and uses the writer to write the resulting text.
    ///
    /// Copies the contents of the reader to the writer, optionally adding header
    /// and footer text.
    ///
    /// - Parameters:
    ///   - reader: The text reader providing the plain text input.
    ///   - writer: The text writer to receive the plain text output.
    public override func convert(_ reader: TextReadable, _ writer: TextWritable) {
        if let header, !header.isEmpty {
            writer.write(header)
        }

        let content = reader.readToEnd()
        if !content.isEmpty {
            writer.write(content)
        }

        if let footer, !footer.isEmpty {
            writer.write(footer)
        }
    }
}
