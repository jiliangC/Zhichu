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
// ParameterEncodingMethod.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// The method to use for encoding Content-Type and Content-Disposition parameter values.
///
/// The MIME specifications specify that the proper method for encoding Content-Type and
/// Content-Disposition parameter values is the method described in
/// [RFC 2231](https://tools.ietf.org/html/rfc2231). However, it is common for
/// some older email clients to improperly encode using the method described in
/// [RFC 2047](https://tools.ietf.org/html/rfc2047) instead.
public enum ParameterEncodingMethod: UInt8, Sendable {
    /// Use the default encoding method set on the ``FormatOptions``.
    case `default` = 0

    /// Use the encoding method described in RFC 2231.
    ///
    /// This is the proper method for encoding Content-Type and Content-Disposition
    /// parameter values according to the MIME specifications.
    case rfc2231 = 1

    /// Use the encoding method described in RFC 2047.
    ///
    /// Use this method for compatibility with older, non-RFC-compliant email clients
    /// that do not properly support RFC 2231 encoding.
    case rfc2047 = 2
}
