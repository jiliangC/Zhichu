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
// TnefComplianceMode.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A TNEF compliance mode.
///
/// Controls how strictly the TNEF parser validates the input stream.
/// Use ``loose`` for maximum compatibility with malformed TNEF data,
/// or ``strict`` for strict validation.
public enum TnefComplianceMode: Int, Sendable {
    /// Use a loose compliance mode, attempting to ignore invalid or corrupt data.
    ///
    /// In loose mode, the parser will attempt to continue reading the TNEF stream
    /// even when it encounters invalid or corrupted data. This mode is recommended
    /// for processing real-world TNEF data that may not strictly conform to the
    /// specification.
    case loose

    /// Use a very strict compliance mode, aborting the parser at the first sign of
    /// invalid or corrupted data.
    ///
    /// In strict mode, the parser will throw a ``TnefException`` as soon as it
    /// encounters any invalid or corrupted data. This mode is useful for validating
    /// TNEF streams or debugging TNEF generation code.
    case strict
}
