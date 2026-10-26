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
// DkimCanonicalizationAlgorithm.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A DKIM canonicalization algorithm.
///
/// Empirical evidence demonstrates that some mail servers and relay systems
/// modify email in transit, potentially invalidating a signature. There are two
/// competing perspectives on such modifications.
///
/// For most signers, mild modification of email is immaterial to the authentication
/// status of the email. For such signers, a canonicalization algorithm that survives
/// modest in-transit modification is preferred (``relaxed``).
///
/// Other signers demand that any modification of the email, however minor, result
/// in a signature verification failure. These signers prefer a canonicalization
/// algorithm that does not tolerate in-transit modification of the signed email
/// (``simple``).
///
/// ## Topics
///
/// ### Canonicalization Algorithms
/// - ``simple``
/// - ``relaxed``
public enum DkimCanonicalizationAlgorithm: Sendable {
    /// The simple canonicalization algorithm.
    ///
    /// This algorithm tolerates almost no modification by mail servers while
    /// the message is in-transit. Use this when you require strict integrity
    /// verification and want any modification to invalidate the signature.
    case simple

    /// The relaxed canonicalization algorithm.
    ///
    /// This algorithm tolerates common modifications by mail servers while
    /// the message is in-transit, such as whitespace replacement and header
    /// field line rewrapping. This is the recommended algorithm for most use
    /// cases as it provides better compatibility with various mail systems.
    case relaxed
}
