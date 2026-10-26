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
// CertificateExtensions.swift
//
// Convenience extensions on Certificate for common operations.
//

import Foundation
@_spi(CMS) import X509
import Crypto
import SwiftASN1

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public extension Certificate {

    /// The SHA-256 fingerprint of the certificate as a lowercase hex string.
    ///
    /// The fingerprint is computed over the DER-encoded certificate bytes.
    /// This can be used to uniquely identify certificates.
    ///
    /// - Returns: A 64-character lowercase hexadecimal string.
    var sha256Fingerprint: String {
        do {
            var serializer = DER.Serializer()
            try serializer.serialize(self)
            let derBytes = serializer.serializedBytes
            let digest = SHA256.hash(data: derBytes)
            return digest.map { String(format: "%02x", $0) }.joined()
        } catch {
            return ""
        }
    }

    /// Email addresses associated with the certificate.
    ///
    /// This property extracts email addresses from:
    /// - The Subject's emailAddress attribute
    /// - The Subject Alternative Name extension (rfc822Name entries)
    ///
    /// - Returns: An array of email addresses, which may be empty.
    var emailAddresses: [String] {
        var emails: [String] = []

        // Check Subject for emailAddress attribute
        for rdn in subject {
            for attribute in rdn {
                // OID for emailAddress: 1.2.840.113549.1.9.1
                if attribute.type.description == "1.2.840.113549.1.9.1" {
                    if let value = String(attribute.value) {
                        emails.append(value)
                    }
                }
            }
        }

        // Check Subject Alternative Name extension
        if let sanExtension = try? extensions.subjectAlternativeNames {
            for name in sanExtension {
                switch name {
                case .rfc822Name(let email):
                    emails.append(email)
                default:
                    break
                }
            }
        }

        return emails
    }

    /// DNS names associated with the certificate from the Subject Alternative Name extension.
    ///
    /// - Returns: An array of DNS names, which may be empty.
    var dnsNames: [String] {
        var names: [String] = []

        if let sanExtension = try? extensions.subjectAlternativeNames {
            for name in sanExtension {
                switch name {
                case .dnsName(let dns):
                    names.append(dns)
                default:
                    break
                }
            }
        }

        return names
    }

    /// The Subject Key Identifier extension value as bytes, if present.
    ///
    /// The SKI is used to identify certificates containing a particular public key.
    ///
    /// - Returns: The SKI bytes, or nil if the extension is not present.
    var subjectKeyIdentifierBytes: [UInt8]? {
        guard let ski = try? extensions.subjectKeyIdentifier else {
            return nil
        }
        return Array(ski.keyIdentifier)
    }

    /// A Boolean value indicating whether this certificate is self-signed.
    ///
    /// A certificate is considered self-signed if the subject and issuer
    /// are identical. Note that this does not verify the signature.
    var isSelfSigned: Bool {
        return subject == issuer
    }

    /// The path length constraint from the Basic Constraints extension.
    ///
    /// - Returns:
    ///   - A non-negative integer if a path length is specified
    ///   - `Int(Int32.max)` if the certificate is a CA with no path length limit
    ///   - `-1` if not a CA or Basic Constraints is not present
    var basicConstraintsPathLength: Int {
        guard let basicConstraints = try? extensions.basicConstraints else {
            return -1
        }

        switch basicConstraints {
        case .notCertificateAuthority:
            return -1
        case .isCertificateAuthority(maxPathLength: let maxPath):
            if let pathLength = maxPath {
                return pathLength
            }
            // Use Int32.max to ensure it fits in SQLite INT column
            return Int(Int32.max)
        }
    }

    /// A Boolean value indicating whether this certificate is a Certificate Authority.
    var isCertificateAuthority: Bool {
        guard let basicConstraints = try? extensions.basicConstraints else {
            return false
        }

        switch basicConstraints {
        case .notCertificateAuthority:
            return false
        case .isCertificateAuthority:
            return true
        }
    }

    /// The key usage flags for this certificate.
    ///
    /// - Returns: The key usage flags, or an empty set if the extension is not present.
    var x509KeyUsage: X509KeyUsageFlags {
        guard let keyUsage = try? extensions.keyUsage else {
            return []
        }

        var flags: X509KeyUsageFlags = []

        if keyUsage.digitalSignature {
            flags.insert(.digitalSignature)
        }
        if keyUsage.nonRepudiation {
            flags.insert(.nonRepudiation)
        }
        if keyUsage.keyEncipherment {
            flags.insert(.keyEncipherment)
        }
        if keyUsage.dataEncipherment {
            flags.insert(.dataEncipherment)
        }
        if keyUsage.keyAgreement {
            flags.insert(.keyAgreement)
        }
        if keyUsage.keyCertSign {
            flags.insert(.keyCertSign)
        }
        if keyUsage.cRLSign {
            flags.insert(.crlSign)
        }
        if keyUsage.encipherOnly {
            flags.insert(.encipherOnly)
        }
        if keyUsage.decipherOnly {
            flags.insert(.decipherOnly)
        }

        return flags
    }

    /// The serial number as a hexadecimal string.
    var serialNumberHex: String {
        return serialNumber.bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// The subject distinguished name as a string.
    var subjectString: String {
        return String(describing: subject)
    }

    /// The issuer distinguished name as a string.
    var issuerString: String {
        return String(describing: issuer)
    }
}
