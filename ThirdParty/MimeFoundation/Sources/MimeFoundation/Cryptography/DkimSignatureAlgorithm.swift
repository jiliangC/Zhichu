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
// DkimSignatureAlgorithm.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A DKIM signature algorithm.
///
/// DomainKeys Identified Mail (DKIM) supports several signature algorithms
/// for signing email messages. This enum represents the available algorithms.
///
/// ## Topics
///
/// ### Signature Algorithms
/// - ``rsaSha1``
/// - ``rsaSha256``
/// - ``ed25519Sha256``
public enum DkimSignatureAlgorithm: Sendable {
    /// The RSA-SHA1 signature algorithm.
    ///
    /// - Warning: Due to the recognized weakness of the SHA-1 hash algorithm,
    ///   it is recommended that this algorithm NOT be used. Use ``rsaSha256``
    ///   or ``ed25519Sha256`` instead.
    case rsaSha1

    /// The RSA-SHA256 signature algorithm.
    ///
    /// This is the most widely supported and recommended algorithm for DKIM signatures
    /// when using RSA keys.
    case rsaSha256

    /// The Ed25519-SHA256 signature algorithm.
    ///
    /// This algorithm uses elliptic curve cryptography (Ed25519) with SHA-256 hashing.
    /// It provides strong security with smaller key sizes compared to RSA.
    case ed25519Sha256
}
