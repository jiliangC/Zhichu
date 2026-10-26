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
// DkimPublicKey.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Crypto
import _CryptoExtras

/// A DKIM public key for signature verification.
///
/// This enum wraps the cryptographic public keys used for DKIM verification,
/// supporting both RSA and Ed25519 key types.
///
/// DKIM public keys are typically retrieved from DNS TXT records at the location
/// `{selector}._domainkey.{domain}` and parsed using ``DkimPublicKeyLocatorBase/getPublicKey(_:)``.
///
/// ## Topics
///
/// ### Key Types
/// - ``rsa(_:)``
/// - ``ed25519(_:)``
public enum DkimPublicKey: Sendable {
    /// An RSA public key for RSA-SHA1 or RSA-SHA256 verification.
    case rsa(_RSA.Signing.PublicKey)
    /// An Ed25519 public key for Ed25519-SHA256 verification.
    case ed25519(Curve25519.Signing.PublicKey)
}
