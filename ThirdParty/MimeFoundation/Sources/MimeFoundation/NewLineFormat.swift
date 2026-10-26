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
// NewLineFormat.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A new-line format.
///
/// There are two commonly used line-endings used by modern Operating Systems.
/// Unix-based systems such as Linux and macOS use a single character (`'\n'` aka LF)
/// to represent the end of line where-as Windows (or DOS) uses a sequence of two
/// characters (`"\r\n"` aka CRLF). Most text-based network protocols such as SMTP,
/// POP3, and IMAP use the CRLF sequence as well.
public enum NewLineFormat: UInt8, Sendable {
    /// The Unix new-line format (`"\n"`).
    ///
    /// This is the standard line ending used on Unix-based systems like Linux and macOS.
    case unix

    /// The DOS new-line format (`"\r\n"`).
    ///
    /// This is the standard line ending used on Windows systems and is also used
    /// by most text-based network protocols such as SMTP, POP3, and IMAP.
    case dos

    /// A mixed new-line format.
    ///
    /// This value indicates that some lines use Unix-based line endings and
    /// other lines use DOS-based line endings.
    case mixed
}
