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
// FormatOptions.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Format options for serializing various MIME objects.
///
/// Represents the available options for formatting MIME messages and entities
/// when writing them to a stream.
public struct FormatOptions: Sendable {
    /// The minimum allowed line length for MIME content.
    ///
    /// Lines shorter than this value may cause compatibility issues with some mail clients.
    public static let minimumLineLength = 60

    /// The maximum allowed line length for MIME content.
    ///
    /// According to RFC 5322, lines in email messages should not exceed 998 characters
    /// (excluding the CRLF line ending).
    public static let maximumLineLength = 998

    /// The default maximum line length.
    ///
    /// The recommended maximum line length is 78 characters, which provides a good
    /// balance between readability and compatibility.
    public static let defaultMaxLineLength = 78

    /// The default formatting options.
    ///
    /// If a custom `FormatOptions` is not provided to methods such as
    /// `MimeMessage.writeTo(_:options:)`, the default options will be used.
    public static var `default`: FormatOptions { FormatOptions() }

    /// The maximum line length used by the encoders.
    ///
    /// The encoders use this value to determine where to place line breaks.
    /// This value specifies the maximum line length to use when line-wrapping headers.
    ///
    /// The value must be between ``minimumLineLength`` and ``maximumLineLength``.
    public var maxLineLength: Int

    /// The new-line format to use when writing the message or entity to a stream.
    ///
    /// Specifies the new-line encoding to use when serializing MIME content.
    public var newLineFormat: NewLineFormat

    /// Whether the formatter should ensure that messages end with a new-line sequence.
    ///
    /// By default, when writing a `MimeMessage` to a stream, the serializer attempts to
    /// maintain byte-for-byte compatibility with the original stream that the message
    /// was parsed from. This means that if the original message stream did not end with
    /// a new-line sequence, then the output of writing the message back to a stream will
    /// also not end with a new-line sequence.
    ///
    /// Set this property to `true` to ensure that writing the message back to a stream
    /// will always end with a new-line sequence.
    public var ensureNewLine: Bool

    /// Whether the new "Internationalized Email" formatting standards should be used.
    ///
    /// The new "Internationalized Email" format is defined by
    /// [RFC 6530](https://tools.ietf.org/html/rfc6530) and
    /// [RFC 6532](https://tools.ietf.org/html/rfc6532).
    ///
    /// This feature should only be used when formatting messages meant to be sent via
    /// SMTP using the SMTPUTF8 extension ([RFC 6531](https://tools.ietf.org/html/rfc6531))
    /// or when appending messages to an IMAP folder via UTF8 APPEND
    /// ([RFC 6855](https://tools.ietf.org/html/rfc6855)).
    public var international: Bool

    /// Whether the formatter should allow mixed charsets in the headers.
    ///
    /// When this option is enabled, the MIME formatter will try to use us-ascii and/or
    /// iso-8859-1 to encode headers when appropriate rather than being forced to use the
    /// specified charset for all encoded-word tokens in order to maximize readability.
    ///
    /// Unfortunately, mail clients like Outlook and Thunderbird do not treat
    /// encoded-word tokens individually and assume that all tokens are encoded using the
    /// charset declared in the first encoded-word token despite the specification
    /// explicitly stating that each encoded-word token should be treated independently.
    public var allowMixedHeaderCharsets: Bool

    /// The method to use for encoding Content-Type and Content-Disposition parameter values.
    ///
    /// The MIME specifications specify that the proper method for encoding Content-Type
    /// and Content-Disposition parameter values is the method described in
    /// [RFC 2231](https://tools.ietf.org/html/rfc2231). However, it is common for
    /// some older email clients to improperly encode using the method described in
    /// [RFC 2047](https://tools.ietf.org/html/rfc2047) instead.
    public var parameterEncodingMethod: ParameterEncodingMethod

    /// Whether Content-Type and Content-Disposition parameter values should always be quoted.
    ///
    /// Technically, Content-Type and Content-Disposition parameter values only require
    /// quoting when they contain characters that have special meaning to a MIME parser.
    /// However, for compatibility with email processing solutions that do not properly
    /// adhere to the MIME specifications, this property can be used to force quoting
    /// parameter values that would normally not require quoting.
    public var alwaysQuoteParameterValues: Bool

    /// Initializes a new instance of `FormatOptions` with default values.
    ///
    /// Creates a new set of formatting options for use with methods such as
    /// `MimeMessage.writeTo(_:options:)`.
    public init() {
        self.maxLineLength = Self.defaultMaxLineLength
        self.ensureNewLine = false
        self.international = false
        self.allowMixedHeaderCharsets = false
        self.parameterEncodingMethod = .rfc2231
        self.alwaysQuoteParameterValues = false
        let os = ProcessInfo.processInfo.environment["OS"]?.lowercased()
        self.newLineFormat = (os == "windows_nt") ? .dos : .unix
    }

    /// The new-line string to use when formatting content.
    ///
    /// Returns `"\n"` for Unix format or `"\r\n"` for DOS format.
    public var newLine: String {
        newLineFormat == .unix ? "\n" : "\r\n"
    }

    /// The new-line bytes to use when formatting content.
    ///
    /// Returns `[0x0A]` (LF) for Unix format or `[0x0D, 0x0A]` (CRLF) for DOS format.
    public var newLineBytes: [UInt8] {
        newLineFormat == .unix ? [0x0A] : [0x0D, 0x0A]
    }

    /// Creates a copy of this `FormatOptions` instance.
    ///
    /// - Returns: An identical copy of the current instance.
    public func copy() -> FormatOptions {
        self
    }
}
