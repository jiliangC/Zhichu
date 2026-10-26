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
// X509CertificateRecord.swift
//
// Certificate metadata record for storage and retrieval.
//

import Foundation
@_spi(CMS) import X509

/// Encryption algorithms supported for S/MIME.
///
/// This enum represents the various encryption algorithms that a recipient
/// may support, as indicated in S/MIME capabilities.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public enum EncryptionAlgorithm: String, Codable, Sendable {
    /// AES-256 in CBC mode.
    case aes256cbc = "aes256-cbc"
    /// AES-192 in CBC mode.
    case aes192cbc = "aes192-cbc"
    /// AES-128 in CBC mode.
    case aes128cbc = "aes128-cbc"
    /// AES-256 in GCM mode.
    case aes256gcm = "aes256-gcm"
    /// AES-192 in GCM mode.
    case aes192gcm = "aes192-gcm"
    /// AES-128 in GCM mode.
    case aes128gcm = "aes128-gcm"
    /// Triple DES in CBC mode (legacy).
    case des3cbc = "3des-cbc"
    /// RC2 with 128-bit key (legacy).
    case rc2_128 = "rc2-128"
    /// RC2 with 64-bit key (legacy).
    case rc2_64 = "rc2-64"
    /// RC2 with 40-bit key (legacy, insecure).
    case rc2_40 = "rc2-40"
}

/// A record containing an X.509 certificate and associated metadata.
///
/// This struct represents a certificate as stored in a certificate database,
/// including metadata such as trust status, S/MIME capabilities, and an
/// optional associated private key.
///
/// ## Usage
///
/// ```swift
/// let record = X509CertificateRecord(
///     certificate: certificate,
///     privateKey: nil,
///     isTrusted: false
/// )
/// print("Fingerprint: \(record.fingerprint)")
/// print("Email: \(record.subjectEmail ?? "none")")
/// ```
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct X509CertificateRecord: Sendable {
    /// The database record ID, or 0 if not yet stored.
    public var id: Int

    /// Whether this certificate is explicitly trusted.
    public var isTrusted: Bool

    /// The X.509 certificate.
    public let certificate: Certificate

    /// The private key associated with this certificate, if available.
    public var privateKey: Certificate.PrivateKey?

    /// The encryption algorithms supported by this certificate's owner.
    ///
    /// This is typically populated from S/MIME capabilities received in
    /// signed messages from this user.
    public var algorithms: [EncryptionAlgorithm]?

    /// When the algorithms list was last updated.
    public var algorithmsUpdated: Date

    /// Creates a new certificate record.
    ///
    /// - Parameters:
    ///   - certificate: The X.509 certificate.
    ///   - privateKey: The associated private key, if any.
    ///   - isTrusted: Whether the certificate is explicitly trusted.
    ///   - algorithms: Supported encryption algorithms.
    ///   - algorithmsUpdated: When the algorithms were last updated.
    ///   - id: The database record ID.
    public init(
        certificate: Certificate,
        privateKey: Certificate.PrivateKey? = nil,
        isTrusted: Bool = false,
        algorithms: [EncryptionAlgorithm]? = nil,
        algorithmsUpdated: Date = Date(timeIntervalSince1970: 0),
        id: Int = 0
    ) {
        self.certificate = certificate
        self.privateKey = privateKey
        self.isTrusted = isTrusted
        self.algorithms = algorithms
        self.algorithmsUpdated = algorithmsUpdated
        self.id = id
    }

    // MARK: - Computed Properties from Certificate

    /// Whether this certificate is a trust anchor (root CA).
    ///
    /// A certificate is considered an anchor if it is trusted and
    /// is a certificate authority.
    public var isAnchor: Bool {
        return isTrusted && certificate.isCertificateAuthority
    }

    /// The basic constraints path length, or -1 if not a CA.
    public var basicConstraints: Int {
        return certificate.basicConstraintsPathLength
    }

    /// The key usage flags for this certificate.
    public var keyUsage: X509KeyUsageFlags {
        return certificate.x509KeyUsage
    }

    /// The not-before date of the certificate's validity period.
    public var notBefore: Date {
        return certificate.notValidBefore
    }

    /// The not-after date of the certificate's validity period.
    public var notAfter: Date {
        return certificate.notValidAfter
    }

    /// The issuer distinguished name.
    public var issuerName: String {
        return certificate.issuerString
    }

    /// The serial number as a hex string.
    public var serialNumber: String {
        return certificate.serialNumberHex
    }

    /// The subject distinguished name.
    public var subjectName: String {
        return certificate.subjectString
    }

    /// The SHA-256 fingerprint of the certificate.
    public var fingerprint: String {
        return certificate.sha256Fingerprint
    }

    /// The subject key identifier bytes, if present.
    public var subjectKeyIdentifier: [UInt8]? {
        return certificate.subjectKeyIdentifierBytes
    }

    /// The subject key identifier as a hex string, if present.
    public var subjectKeyIdentifierHex: String? {
        guard let ski = subjectKeyIdentifier else { return nil }
        return ski.map { String(format: "%02x", $0) }.joined()
    }

    /// The primary email address from the certificate, if any.
    ///
    /// Returns the first email address found in the Subject or SAN.
    public var subjectEmail: String? {
        return certificate.emailAddresses.first
    }

    /// All email addresses from the certificate.
    public var subjectEmails: [String] {
        return certificate.emailAddresses
    }

    /// DNS names from the Subject Alternative Name extension.
    public var subjectDnsNames: [String] {
        return certificate.dnsNames
    }

    /// A Boolean indicating whether the certificate is currently valid.
    ///
    /// This checks whether the current date falls within the certificate's
    /// validity period.
    public var isValid: Bool {
        return isValid(at: Date())
    }

    /// Checks whether the certificate is valid at a specific date.
    ///
    /// - Parameter date: The date to check validity for.
    /// - Returns: `true` if the certificate is valid at the specified date.
    public func isValid(at date: Date) -> Bool {
        return date >= notBefore && date <= notAfter
    }

    /// A Boolean indicating whether this record has an associated private key.
    public var hasPrivateKey: Bool {
        return privateKey != nil
    }
}

// MARK: - Hashable & Equatable

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
extension X509CertificateRecord: Hashable {
    public static func == (lhs: X509CertificateRecord, rhs: X509CertificateRecord) -> Bool {
        // Two records are equal if they have the same fingerprint
        return lhs.fingerprint == rhs.fingerprint
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fingerprint)
    }
}
