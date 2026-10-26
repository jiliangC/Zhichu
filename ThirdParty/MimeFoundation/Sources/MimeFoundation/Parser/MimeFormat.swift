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
// MimeFormat.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// The format of the MIME stream.
///
/// This enumeration specifies the expected format of the MIME data being parsed.
public enum MimeFormat: UInt8, Sendable {
    /// The stream contains a single MIME entity or message.
    ///
    /// Use this format when parsing a standard email message or MIME entity
    /// from a stream that contains exactly one message.
    case entity = 0

    /// The stream is in the Unix mbox format and may contain more than a single message.
    ///
    /// The mbox format is a common file format for storing collections of email messages.
    /// Each message in an mbox file is preceded by a "From " line (the mbox marker).
    /// Use this format when parsing mbox files or streams containing multiple messages.
    case mbox = 1
}

public extension MimeFormat {
    /// The default stream format.
    ///
    /// The default format is ``entity``, indicating that the stream contains
    /// a single MIME entity or message.
    static var `default`: MimeFormat { .entity }
}
