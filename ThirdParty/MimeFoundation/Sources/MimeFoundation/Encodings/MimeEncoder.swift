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
// MimeEncoder.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Errors that can occur during MIME encoding or decoding operations.
public enum MimeCodingError: Error, Equatable, Sendable {
    /// The start index is outside the valid range of the input buffer.
    case startIndexOutOfRange
    /// The length parameter is invalid (negative or extends beyond the input buffer).
    case lengthOutOfRange
    /// The output buffer is not large enough to contain the encoded or decoded content.
    /// Use the ``MimeEncoder/estimateOutputLength(_:)`` or ``MimeDecoder/estimateOutputLength(_:)``
    /// method to properly determine the necessary length of the output buffer.
    case outputTooSmall
}

/// A protocol for incrementally encoding content.
///
/// ``MimeEncoder`` provides an interface for encoding content using various MIME encoding schemes
/// such as Base64, Quoted-Printable, UUEncode, and others. The encoder maintains internal state
/// to support incremental encoding of large content streams.
public protocol MimeEncoder {
    /// The content encoding that this encoder supports.
    ///
    /// Gets the encoding type that the encoder uses to encode content.
    var encoding: ContentEncoding { get }

    /// Creates a copy of this encoder with its current state.
    ///
    /// Creates a new ``MimeEncoder`` with exactly the same state as the current encoder,
    /// allowing the encoding process to be forked or saved at a particular point.
    ///
    /// - Returns: A new ``MimeEncoder`` with identical state.
    func copy() -> any MimeEncoder

    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// This method can be used to allocate an output buffer of the appropriate size
    /// before calling ``encode(_:startIndex:length:output:)`` or ``flush(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be encoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    func estimateOutputLength(_ inputLength: Int) -> Int

    /// Encodes the specified input into the output buffer.
    ///
    /// Encodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the encoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing bytes to encode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to encode from the input buffer.
    ///   - output: The output buffer to write encoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    func encode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int

    /// Encodes the specified input into the output buffer, flushing any internal buffer state.
    ///
    /// Encodes the specified input into the output buffer, flushing any internal state as well.
    /// This method should be called when encoding the final chunk of data to ensure all
    /// buffered content is written to the output. The output buffer should be large enough
    /// to hold all the encoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing bytes to encode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to encode from the input buffer.
    ///   - output: The output buffer to write encoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    func flush(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int

    /// Resets the encoder to its initial state.
    ///
    /// Resets the internal state of the encoder, allowing it to be reused for encoding
    /// new content from the beginning.
    func reset()
}

/// A protocol for incrementally decoding content.
///
/// ``MimeDecoder`` provides an interface for decoding content that was encoded using various
/// MIME encoding schemes such as Base64, Quoted-Printable, UUEncode, and others. The decoder
/// maintains internal state to support incremental decoding of large content streams.
public protocol MimeDecoder {
    /// The content encoding that this decoder supports.
    ///
    /// Gets the encoding type that the decoder uses to decode content.
    var encoding: ContentEncoding { get }

    /// Creates a copy of this decoder with its current state.
    ///
    /// Creates a new ``MimeDecoder`` with exactly the same state as the current decoder,
    /// allowing the decoding process to be forked or saved at a particular point.
    ///
    /// - Returns: A new ``MimeDecoder`` with identical state.
    func copy() -> any MimeDecoder

    /// Estimates the number of bytes needed to decode the specified number of input bytes.
    ///
    /// This method can be used to allocate an output buffer of the appropriate size
    /// before calling ``decode(_:startIndex:length:output:)``.
    ///
    /// - Parameter inputLength: The number of input bytes to be decoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    func estimateOutputLength(_ inputLength: Int) -> Int

    /// Decodes the specified input into the output buffer.
    ///
    /// Decodes the specified input into the output buffer. The output buffer should be large enough
    /// to hold all the decoded input. For estimating the size needed for the output buffer,
    /// see ``estimateOutputLength(_:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing bytes to decode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to decode from the input buffer.
    ///   - output: The output buffer to write decoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    func decode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int

    /// Resets the decoder to its initial state.
    ///
    /// Resets the internal state of the decoder, allowing it to be reused for decoding
    /// new content from the beginning.
    func reset()
}

/// A protocol for encoding content according to RFC 2047 (MIME encoded-word) specifications.
///
/// RFC 2047 defines a mechanism for encoding non-ASCII text in message headers, allowing
/// character sets other than ASCII to be used in header field values.
public protocol Rfc2047Encoder {
    /// The encoding character used in the RFC 2047 encoded-word.
    ///
    /// This is typically 'B' for Base64 encoding or 'Q' for Quoted-Printable encoding.
    var encoding: Character { get }

    /// Estimates the number of bytes needed to encode the specified number of input bytes.
    ///
    /// - Parameter inputLength: The number of input bytes to be encoded.
    /// - Returns: The estimated maximum number of bytes needed in the output buffer.
    func estimateOutputLength(_ inputLength: Int) -> Int

    /// Encodes the specified input into the output buffer according to RFC 2047.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing bytes to encode.
    ///   - startIndex: The starting index within the input buffer.
    ///   - length: The number of bytes to encode from the input buffer.
    ///   - output: The output buffer to write encoded bytes to.
    /// - Returns: The number of bytes written to the output buffer.
    /// - Throws: ``MimeCodingError/startIndexOutOfRange`` if the start index is invalid.
    /// - Throws: ``MimeCodingError/lengthOutOfRange`` if the length is invalid.
    /// - Throws: ``MimeCodingError/outputTooSmall`` if the output buffer is not large enough.
    func encode(_ input: [UInt8], startIndex: Int, length: Int, output: inout [UInt8]) throws -> Int
}

/// Specifies the mode for Q-encoding in RFC 2047 encoded-words.
///
/// The Q-encoding mode determines which characters are considered safe and do not require encoding.
/// Different contexts in email headers have different requirements for which characters must be encoded.
public enum QEncodeMode: UInt8, Sendable {
    /// The phrase mode for Q-encoding.
    ///
    /// In phrase mode, the Q-encoding is used in contexts where the encoded text appears as a "phrase"
    /// in an email header, such as the display name in a From or To header. This mode has stricter
    /// encoding requirements.
    case phrase

    /// The text mode for Q-encoding.
    ///
    /// In text mode, the Q-encoding is used in contexts where the encoded text appears as unstructured
    /// text in an email header. This mode has more relaxed encoding requirements compared to phrase mode.
    case text
}
