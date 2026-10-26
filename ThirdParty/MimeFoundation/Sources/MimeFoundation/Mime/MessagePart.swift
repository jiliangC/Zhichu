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
// MessagePart.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Errors that can occur when working with message parts.
public enum MessagePartError: Error, Equatable, Sendable {
    /// A duplicate message was specified when creating the part.
    case duplicateMessage

    /// An invalid argument was provided.
    case invalidArgument

    /// The maximum line length value is invalid.
    case invalidMaxLineLength
}

/// A MIME part containing an encapsulated message.
///
/// A ``MessagePart`` is a MIME entity with a Content-Type of message/rfc822 or
/// message/news and is used to encapsulate another MIME message within the parent
/// message. This is commonly used for forwarding messages or for bounce notifications.
///
/// ## Topics
///
/// ### Creating Message Parts
/// - ``init(_:)``
/// - ``init()``
/// - ``init(_:_:)``
/// - ``init(_:args:)``
///
/// ### Message Content
/// - ``message``
///
/// ### Preparing for Transport
/// - ``prepare(_:maxLineLength:)``
open class MessagePart: MimeEntity {
    /// The encapsulated message.
    ///
    /// The MIME message contained within this message part.
    public var message: MimeMessage?

    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    /// Initializes a new message part with the specified subtype.
    ///
    /// Creates a new message part with the media type "message" and the specified subtype.
    ///
    /// - Parameter subtype: The media subtype (e.g., "rfc822", "news").
    public convenience init(_ subtype: String) {
        guard let contentType = try? ContentType("message", subtype) else {
            preconditionFailure("Invalid subtype '\(subtype)' for message content type")
        }
        self.init(contentType)
    }

    /// Initializes a new message part with the default subtype.
    ///
    /// Creates a new message/rfc822 part.
    public convenience init() {
        self.init("rfc822")
    }

    /// Initializes a new message part with the specified subtype and arguments.
    ///
    /// - Parameters:
    ///   - subtype: The media subtype (e.g., "rfc822", "news").
    ///   - args: Additional initialization arguments including headers and the encapsulated message.
    /// - Throws: ``MessagePartError/duplicateMessage`` if more than one message is specified,
    ///           or ``MessagePartError/invalidArgument`` if an unknown argument type is provided.
    public convenience init(_ subtype: String, _ args: Any?...) throws {
        try self.init(subtype, args: args)
    }

    public convenience init(_ subtype: String, args: [Any?]) throws {
        self.init(subtype)
        try applyArgs(args)
    }

    /// Prepares the encapsulated message for transport using the specified encoding constraints.
    ///
    /// Ensures that the encapsulated message is properly encoded according to the specified
    /// constraints, preparing it for transmission over protocols that may have encoding or
    /// line length restrictions.
    ///
    /// - Parameters:
    ///   - constraint: The encoding constraint to apply.
    ///   - maxLineLength: The maximum line length. Defaults to 78 characters.
    /// - Throws: ``MessagePartError/invalidMaxLineLength`` if the max line length is invalid.
    public func prepare(_ constraint: EncodingConstraint, maxLineLength: Int = FormatOptions.defaultMaxLineLength) throws {
        if maxLineLength < FormatOptions.minimumLineLength || maxLineLength > FormatOptions.maximumLineLength {
            throw MessagePartError.invalidMaxLineLength
        }
        try message?.prepare(constraint, maxLineLength: maxLineLength)
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    public override func writeTo(_ options: FormatOptions, _ stream: MimeStream) throws {
        try super.writeTo(options, stream)
    }

    internal override func writeBody(_ options: FormatOptions, stream: MimeStream) throws {
        if let message {
            try message.writeTo(options, stream)
        }
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
                    throw MessagePartError.duplicateMessage
                }
                message = value
                continue
            }
            throw MessagePartError.invalidArgument
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
