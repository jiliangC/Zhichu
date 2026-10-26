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
// EncoderFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A filter for encoding MIME content.
///
/// ``EncoderFilter`` uses a ``MimeEncoder`` to incrementally encode data
/// as it passes through a ``FilteredStream``. This is useful for converting
/// raw binary data into a text-safe encoding for transmission.
///
/// ## Overview
///
/// The filter supports several content transfer encodings:
///
/// - **Base64**: Encodes binary data into ASCII text using 64 characters
/// - **Quoted-Printable**: Encodes text with minimal overhead for mostly ASCII content
/// - **UUEncode**: Legacy Unix-to-Unix encoding
///
/// ## Example Usage
///
/// ```swift
/// // Create a filtered stream with Base64 encoding
/// let output = MemoryBlockStream()
/// let filtered = try FilteredStream(output)
/// try filtered.add(EncoderFilter.create(.base64))
///
/// // Write raw data - it will be Base64 encoded
/// try filtered.write(binaryData, offset: 0, count: binaryData.count)
/// try filtered.flush()
/// ```
///
/// ## Factory Methods
///
/// Use the ``create(_:)-31q2c`` method to create an encoder filter for a specific
/// ``ContentEncoding``, or ``create(_:)-1tawh`` to create one from an encoding name string.
public final class EncoderFilter: MimeFilterBase {
    /// Gets the content encoding that this filter uses.
    ///
    /// The encoding determines how the input data is transformed.
    /// For example, ``.base64`` will convert binary data to Base64 text.
    public let encoding: ContentEncoding

    private var encoder: MimeEncoder

    /// Initializes a new instance of the ``EncoderFilter`` class.
    ///
    /// Creates a new encoder filter using the specified encoder.
    ///
    /// - Parameter encoder: A specific encoder for the filter to use.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let encoder = Base64Encoder()
    /// let filter = EncoderFilter(encoder)
    /// ```
    public init(_ encoder: MimeEncoder) {
        self.encoder = encoder
        self.encoding = encoder.encoding
    }

    /// Filters the specified input.
    ///
    /// Encodes the specified input buffer starting at the given index,
    /// spanning across the specified number of bytes.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to encode.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: On return, contains the output index (always 0).
    ///   - outputLength: On return, contains the length of the encoded output.
    ///   - flush: If `true`, all internally buffered data should be flushed
    ///     to the output buffer.
    ///
    /// - Returns: The output buffer containing the encoded data.
    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        ensureOutputSize(encoder.estimateOutputLength(length), preserve: false)
        var output = self.output
        let written = (try? encoder.encode(input, startIndex: startIndex, length: length, output: &output)) ?? 0
        outputIndex = 0
        outputLength = written
        return output
    }

    /// Filters the specified input, flushing all internally buffered data to the output.
    ///
    /// Encodes the specified input buffer and flushes any remaining buffered data.
    /// This should be called when no more input data is available.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to encode.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: On return, contains the output index (always 0).
    ///   - outputLength: On return, contains the length of the encoded output.
    ///
    /// - Returns: The output buffer containing the encoded data plus any
    ///   remaining buffered data.
    public override func flush(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int) -> [UInt8] {
        ensureOutputSize(encoder.estimateOutputLength(length) + 8, preserve: false)
        var output = self.output
        let written = (try? encoder.flush(input, startIndex: startIndex, length: length, output: &output)) ?? 0
        outputIndex = 0
        outputLength = written
        return output
    }

    /// Resets the filter to its initial state.
    ///
    /// Resets both the underlying encoder and the filter's output buffer.
    public override func reset() {
        encoder.reset()
        super.reset()
    }

    /// Creates a filter that will encode using the specified encoding.
    ///
    /// Creates a new ``MimeFilter`` for the specified encoding. If the encoding
    /// does not require transformation (such as 7bit, 8bit, or binary), a
    /// pass-through filter is returned.
    ///
    /// - Parameter encoding: The encoding to create a filter for.
    ///
    /// - Returns: A new encoder filter, or a ``PassThroughFilter`` if no encoding
    ///   is needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let filter = EncoderFilter.create(.base64)
    /// ```
    public static func create(_ encoding: ContentEncoding?) -> MimeFilter {
        guard let encoding else {
            return PassThroughFilter()
        }
        switch encoding {
        case .base64:
            return EncoderFilter(Base64Encoder())
        case .quotedPrintable:
            return EncoderFilter(QuotedPrintableEncoder())
        case .uuEncode:
            return EncoderFilter(UUEncoder())
        default:
            return PassThroughFilter()
        }
    }

    /// Creates a filter that will encode using the specified encoding name.
    ///
    /// Creates a new ``MimeFilter`` for the specified encoding name. The name
    /// is case-insensitive and whitespace is trimmed.
    ///
    /// Supported encoding names:
    /// - `"base64"`: Base64 encoding
    /// - `"quoted-printable"`: Quoted-Printable encoding
    /// - `"x-uuencode"`, `"uuencode"`: UUEncode encoding
    /// - `"7bit"`, `"8bit"`, `"binary"`: Pass-through (no encoding)
    ///
    /// - Parameter encoding: The name of the encoding to create a filter for.
    ///
    /// - Returns: A new encoder filter, or a ``PassThroughFilter`` if the encoding
    ///   name is not recognized or no encoding is needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let filter = EncoderFilter.create("base64")
    /// ```
    public static func create(_ encoding: String?) -> MimeFilter {
        guard let encoding else {
            return PassThroughFilter()
        }
        switch encoding.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "base64":
            return EncoderFilter(Base64Encoder())
        case "quoted-printable":
            return EncoderFilter(QuotedPrintableEncoder())
        case "x-uuencode", "uuencode":
            return EncoderFilter(UUEncoder())
        case "7bit", "8bit", "binary":
            return PassThroughFilter()
        default:
            return PassThroughFilter()
        }
    }
}
