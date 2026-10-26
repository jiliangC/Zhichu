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
// TnefAttachMethod.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// The TNEF attach method.
///
/// The ``TnefAttachMethod`` enum contains a list of possible values for
/// the ``TnefPropertyId/attachMethod`` property. This property specifies
/// how the attachment data is stored in the TNEF stream.
public enum TnefAttachMethod: Int, Sendable {
    /// No AttachMethod specified.
    ///
    /// The attachment method is not specified or unknown.
    case none            = 0

    /// The attachment is a binary blob and SHOULD appear in the
    /// ``TnefAttributeTag/attachData`` attribute.
    ///
    /// This is the most common attachment method, where the attachment
    /// content is stored directly as binary data.
    case byValue         = 1

    /// The attachment is an embedded TNEF message stream and MUST appear
    /// in the ``TnefPropertyId/attachData`` property of the
    /// ``TnefAttributeTag/attachment`` attribute.
    ///
    /// This method is used when the attachment is itself another TNEF-encoded
    /// message, typically used for forwarded messages.
    case embeddedMessage = 5

    /// The attachment is an OLE stream and MUST appear
    /// in the ``TnefPropertyId/attachData`` property of the
    /// ``TnefAttributeTag/attachment`` attribute.
    ///
    /// This method is used for OLE (Object Linking and Embedding) objects,
    /// which are typically Microsoft Office documents or other embedded objects.
    case ole             = 6
}
