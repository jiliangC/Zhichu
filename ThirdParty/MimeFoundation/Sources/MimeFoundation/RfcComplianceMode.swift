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
// RfcComplianceMode.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// An RFC compliance mode.
///
/// This enumeration is used to control how strictly the parser adheres to the
/// RFC specifications when parsing MIME content.
public enum RfcComplianceMode: Int, Sendable {
    /// Attempt to be even more liberal in accepting broken and/or invalid formatting.
    ///
    /// This mode provides the maximum level of compatibility with malformed email content.
    case looser = -1

    /// Attempt to be more liberal accepting broken and/or invalid formatting.
    ///
    /// This is the default mode and provides good compatibility with existing
    /// (broken) mail clients and other mail software such as sloppily written scripts.
    case loose = 0

    /// Do not attempt to be overly liberal in accepting broken and/or invalid formatting.
    ///
    /// Use this mode when you need stricter RFC compliance and want to reject
    /// malformed content.
    case strict = 1
}
