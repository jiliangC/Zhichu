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
// X509KeyUsageFlags.swift
//
// Key usage flags for X.509 certificates.
//

import Foundation

/// Key usage flags for X.509 certificates.
///
/// These flags indicate the permitted uses for a certificate's public key
/// as defined in RFC 5280 Section 4.2.1.3.
///
/// ## Usage
///
/// ```swift
/// let flags: X509KeyUsageFlags = [.digitalSignature, .keyEncipherment]
/// if flags.contains(.digitalSignature) {
///     print("Certificate can be used for digital signatures")
/// }
/// ```
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct X509KeyUsageFlags: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The public key may be used for verifying digital signatures.
    ///
    /// Used for authentication, data integrity, and non-repudiation purposes
    /// other than signing certificates or CRLs.
    public static let digitalSignature = X509KeyUsageFlags(rawValue: 1 << 0)

    /// The public key may be used for verifying digital signatures that
    /// provide non-repudiation services.
    ///
    /// This prevents the signing entity from falsely denying some action.
    /// Also known as `contentCommitment` in X.509 terminology.
    public static let nonRepudiation = X509KeyUsageFlags(rawValue: 1 << 1)

    /// The public key may be used for enciphering private or secret keys.
    ///
    /// Used when the subject public key is used to encrypt a symmetric key
    /// which is then used to encrypt data.
    public static let keyEncipherment = X509KeyUsageFlags(rawValue: 1 << 2)

    /// The public key may be used for directly enciphering data.
    ///
    /// Used when the subject public key is used to encrypt user data
    /// directly (without an intermediary symmetric cipher).
    public static let dataEncipherment = X509KeyUsageFlags(rawValue: 1 << 3)

    /// The public key may be used for key agreement.
    ///
    /// Used with Diffie-Hellman or other key agreement algorithms where
    /// the public key is used to derive a shared secret.
    public static let keyAgreement = X509KeyUsageFlags(rawValue: 1 << 4)

    /// The public key may be used for verifying certificate signatures.
    ///
    /// Used to identify certificates that can sign other certificates
    /// (i.e., CA certificates).
    public static let keyCertSign = X509KeyUsageFlags(rawValue: 1 << 5)

    /// The public key may be used for verifying CRL signatures.
    ///
    /// Used to identify certificates that can sign certificate revocation lists.
    public static let crlSign = X509KeyUsageFlags(rawValue: 1 << 6)

    /// When keyAgreement is set, the encipherOnly flag indicates that the
    /// public key may be used only for enciphering data during key agreement.
    public static let encipherOnly = X509KeyUsageFlags(rawValue: 1 << 7)

    /// When keyAgreement is set, the decipherOnly flag indicates that the
    /// public key may be used only for deciphering data during key agreement.
    public static let decipherOnly = X509KeyUsageFlags(rawValue: 1 << 8)

    /// No key usage restrictions.
    public static let none: X509KeyUsageFlags = []

    /// All key usage flags set.
    public static let all: X509KeyUsageFlags = [
        .digitalSignature, .nonRepudiation, .keyEncipherment,
        .dataEncipherment, .keyAgreement, .keyCertSign,
        .crlSign, .encipherOnly, .decipherOnly
    ]
}
