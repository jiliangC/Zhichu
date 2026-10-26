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
// TnefAttributeLevel.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A TNEF attribute level.
///
/// TNEF attributes can exist at either the message level or attachment level.
/// This enumeration identifies which level an attribute belongs to.
public enum TnefAttributeLevel: Int, Sendable {
    /// The attribute is a message-level attribute.
    ///
    /// Message-level attributes contain information about the message as a whole,
    /// such as the subject, sender, recipients, and message body.
    case message    = 1

    /// The attribute is an attachment-level attribute.
    ///
    /// Attachment-level attributes contain information about individual attachments,
    /// such as the filename, content type, and attachment data.
    case attachment = 2
}
