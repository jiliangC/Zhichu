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
// TextRfc822Headers.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Errors that can occur when working with ``TextRfc822Headers``.
public enum TextRfc822HeadersError: Error, Equatable, Sendable {
    /// Multiple ``MimeMessage`` instances were provided during initialization.
    case duplicateMessage

    /// An invalid argument type was provided during initialization.
    case invalidArgument
}

/// A MIME part containing message headers as its content.
///
/// Represents MIME entities with a Content-Type of text/rfc822-headers.
///
/// ## Overview
///
/// ``TextRfc822Headers`` is used to represent message headers when they need to
/// be included as a separate MIME part. This is commonly used in email bounce
/// messages or other scenarios where the original message headers need to be
/// preserved separately from the message body.
public final class TextRfc822Headers: MessagePart {
    private static var rfc822HeadersContentType: ContentType {
        guard let ct = try? ContentType("text", "rfc822-headers") else {
            preconditionFailure("Invalid static content type - this is a programming error")
        }
        return ct
    }

    /// Creates a new text/rfc822-headers MIME entity with the specified content type.
    ///
    /// This initializer is typically used by ``MimeParser``.
    ///
    /// - Parameter contentType: The content type.
    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    /// Creates a new text/rfc822-headers MIME entity.
    ///
    /// Creates a new ``TextRfc822Headers`` with a Content-Type of text/rfc822-headers.
    public convenience init() {
        self.init(Self.rfc822HeadersContentType)
    }

    /// Creates a new text/rfc822-headers MIME entity with initialization parameters.
    ///
    /// Creates a new ``TextRfc822Headers`` and initializes it with the provided arguments.
    /// The arguments can include ``Header`` objects, arrays of headers, or a ``MimeMessage``.
    ///
    /// - Parameter args: Initialization parameters (headers, header arrays, or message).
    ///
    /// - Throws: ``TextRfc822HeadersError/duplicateMessage`` if more than one
    ///           ``MimeMessage`` is provided.
    /// - Throws: ``TextRfc822HeadersError/invalidArgument`` if an argument of an
    ///           unsupported type is provided.
    public convenience init(_ args: Any?...) throws {
        try self.init(args: args)
    }

    /// Creates a new text/rfc822-headers MIME entity with an array of initialization parameters.
    ///
    /// Creates a new ``TextRfc822Headers`` and initializes it with the provided arguments.
    /// The arguments can include ``Header`` objects, arrays of headers, or a ``MimeMessage``.
    ///
    /// - Parameter args: An array of initialization parameters.
    ///
    /// - Throws: ``TextRfc822HeadersError/duplicateMessage`` if more than one
    ///           ``MimeMessage`` is provided.
    /// - Throws: ``TextRfc822HeadersError/invalidArgument`` if an argument of an
    ///           unsupported type is provided.
    public convenience init(args: [Any?]) throws {
        self.init()
        try applyArgs(args)
    }

    /// Dispatches to the appropriate visit method for this MIME entity type.
    ///
    /// - Parameter visitor: The visitor that will process this entity.
    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    private func applyArgs(_ args: [Any?]) throws {
        var message: MimeMessage?

        for obj in args {
            guard let obj else { continue }
            if tryInit(obj) {
                continue
            }
            if let value = obj as? MimeMessage {
                if message != nil {
                    throw TextRfc822HeadersError.duplicateMessage
                }
                message = value
                continue
            }
            throw TextRfc822HeadersError.invalidArgument
        }

        if let message {
            self.message = message
        }
    }

    private func tryInit(_ obj: Any) -> Bool {
        if let header = obj as? Header {
            headers.add(header)
            return true
        }
        if let headers = obj as? [Header] {
            for header in headers {
                self.headers.add(header)
            }
            return true
        }
        return false
    }
}
