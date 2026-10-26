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
// DecoderFilter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A filter for decoding MIME content.
///
/// ``DecoderFilter`` uses a ``MimeDecoder`` to incrementally decode data
/// as it passes through a ``FilteredStream``. This is useful for converting
/// encoded content (such as Base64 or Quoted-Printable) back to its original form.
///
/// ## Overview
///
/// The filter supports several content transfer encodings:
///
/// - **Base64**: Decodes Base64-encoded text back to binary data
/// - **Quoted-Printable**: Decodes Quoted-Printable encoded text
/// - **UUEncode**: Decodes legacy Unix-to-Unix encoding
///
/// ## Example Usage
///
/// ```swift
/// // Create a filtered stream with Base64 decoding
/// let input = MemoryStream(base64EncodedData)
/// let filtered = try FilteredStream(input)
/// try filtered.add(DecoderFilter.create(.base64))
///
/// // Read decoded data
/// var buffer = [UInt8](repeating: 0, count: 1024)
/// let bytesRead = try filtered.read(&buffer, offset: 0, count: 1024)
/// ```
///
/// ## Factory Methods
///
/// Use the ``create(_:)-3xd6r`` method to create a decoder filter for a specific
/// ``ContentEncoding``, or ``create(_:)-952hq`` to create one from an encoding name string.
public final class DecoderFilter: MimeFilterBase {
    /// Gets the content encoding that this filter decodes.
    ///
    /// The encoding determines how the input data is transformed.
    /// For example, ``.base64`` will convert Base64 text to binary data.
    public let encoding: ContentEncoding

    private var decoder: MimeDecoder

    /// Initializes a new instance of the ``DecoderFilter`` class.
    ///
    /// Creates a new decoder filter using the specified decoder.
    ///
    /// - Parameter decoder: A specific decoder for the filter to use.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let decoder = Base64Decoder()
    /// let filter = DecoderFilter(decoder)
    /// ```
    public init(_ decoder: MimeDecoder) {
        self.decoder = decoder
        self.encoding = decoder.encoding
    }

    /// Filters the specified input by decoding it.
    ///
    /// Decodes the specified input buffer starting at the given index,
    /// spanning across the specified number of bytes.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing encoded data.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: When this method returns, contains the output index (always 0).
    ///   - outputLength: When this method returns, contains the length of the decoded output.
    ///   - flush: If `true`, all internally buffered data should be flushed to the output buffer.
    ///
    /// - Returns: The output buffer containing the decoded data.
    public override func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        ensureOutputSize(decoder.estimateOutputLength(length), preserve: false)
        var output = self.output
        let written = (try? decoder.decode(input, startIndex: startIndex, length: length, output: &output)) ?? 0
        outputIndex = 0
        outputLength = written
        return output
    }

    /// Resets the filter to its initial state.
    ///
    /// Resets both the underlying decoder and the filter's output buffer.
    public override func reset() {
        decoder.reset()
        super.reset()
    }

    /// Creates a filter that will decode using the specified encoding.
    ///
    /// Creates a new ``MimeFilter`` for the specified encoding. If the encoding
    /// does not require transformation (such as 7bit, 8bit, or binary), a
    /// pass-through filter is returned.
    ///
    /// - Parameter encoding: The encoding to create a filter for.
    ///
    /// - Returns: A new decoder filter, or a ``PassThroughFilter`` if no decoding
    ///   is needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let filter = DecoderFilter.create(.base64)
    /// ```
    public static func create(_ encoding: ContentEncoding?) -> MimeFilter {
        guard let encoding else {
            return PassThroughFilter()
        }
        switch encoding {
        case .base64:
            return DecoderFilter(Base64Decoder())
        case .quotedPrintable:
            return DecoderFilter(QuotedPrintableDecoder())
        case .uuEncode:
            return DecoderFilter(UUDecoder())
        default:
            return PassThroughFilter()
        }
    }

    /// Creates a filter that will decode using the specified encoding name.
    ///
    /// Creates a new ``MimeFilter`` for the specified encoding name. The name
    /// is case-insensitive and whitespace is trimmed.
    ///
    /// Supported encoding names:
    /// - `"base64"`: Base64 decoding
    /// - `"quoted-printable"`: Quoted-Printable decoding
    /// - `"x-uuencode"`, `"uuencode"`: UUEncode decoding
    /// - `"7bit"`, `"8bit"`, `"binary"`: Pass-through (no decoding)
    ///
    /// - Parameter encoding: The name of the encoding to create a filter for.
    ///
    /// - Returns: A new decoder filter, or a ``PassThroughFilter`` if the encoding
    ///   name is not recognized or no decoding is needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let filter = DecoderFilter.create("base64")
    /// ```
    public static func create(_ encoding: String?) -> MimeFilter {
        guard let encoding else {
            return PassThroughFilter()
        }
        switch encoding.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "base64":
            return DecoderFilter(Base64Decoder())
        case "quoted-printable":
            return DecoderFilter(QuotedPrintableDecoder())
        case "x-uuencode", "uuencode":
            return DecoderFilter(UUDecoder())
        case "7bit", "8bit", "binary":
            return PassThroughFilter()
        default:
            return PassThroughFilter()
        }
    }
}
