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
// DigitalSignature.swift
//
// Represents a verified digital signature.
//

import Foundation
@_spi(CMS) import X509

/// Represents the result of verifying a digital signature.
///
/// A `DigitalSignature` contains information about the signer and
/// the verification status of a signature.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct DigitalSignature: Sendable {
    /// The certificate of the entity that created the signature.
    public let signerCertificate: Certificate

    /// The digest algorithm used to create the signature.
    public let digestAlgorithm: DigestAlgorithm

    /// The date and time when the signature was created, if available.
    public let creationDate: Date?

    /// Indicates whether the signature is valid.
    ///
    /// A signature is valid if:
    /// - The cryptographic signature verifies correctly
    /// - The signer's certificate chain validates to a trusted root
    /// - The certificate was valid at the time of signing
    public let isValid: Bool

    /// Creates a new digital signature result.
    ///
    /// - Parameters:
    ///   - signerCertificate: The certificate of the signer.
    ///   - digestAlgorithm: The digest algorithm used.
    ///   - creationDate: The signature creation date, if known.
    ///   - isValid: Whether the signature is valid.
    public init(
        signerCertificate: Certificate,
        digestAlgorithm: DigestAlgorithm,
        creationDate: Date?,
        isValid: Bool
    ) {
        self.signerCertificate = signerCertificate
        self.digestAlgorithm = digestAlgorithm
        self.creationDate = creationDate
        self.isValid = isValid
    }

    /// The subject distinguished name of the signer's certificate.
    public var signerName: String {
        String(describing: signerCertificate.subject)
    }

    /// The issuer distinguished name of the signer's certificate.
    public var issuerName: String {
        String(describing: signerCertificate.issuer)
    }

    /// The serial number of the signer's certificate.
    public var certificateSerialNumber: String {
        String(describing: signerCertificate.serialNumber)
    }
}

/// A collection of digital signatures from a signed message.
///
/// A signed message may contain multiple signatures from different signers.
/// This collection provides access to all signatures and convenience
/// methods for checking overall validity.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct DigitalSignatureCollection: Sendable, RandomAccessCollection {
    public typealias Element = DigitalSignature
    public typealias Index = Int

    private let signatures: [DigitalSignature]

    /// Creates a new digital signature collection.
    ///
    /// - Parameter signatures: The signatures to include in the collection.
    public init(_ signatures: [DigitalSignature]) {
        self.signatures = signatures
    }

    /// The start index of the collection.
    public var startIndex: Int { signatures.startIndex }

    /// The end index of the collection.
    public var endIndex: Int { signatures.endIndex }

    /// Returns the index after the given index.
    public func index(after i: Int) -> Int { signatures.index(after: i) }

    /// Accesses the signature at the specified index.
    public subscript(position: Int) -> DigitalSignature {
        signatures[position]
    }

    /// The number of signatures in the collection.
    public var count: Int { signatures.count }

    /// Indicates whether all signatures in the collection are valid.
    public var allValid: Bool {
        signatures.allSatisfy { $0.isValid }
    }

    /// Indicates whether any signature in the collection is valid.
    public var anyValid: Bool {
        signatures.contains { $0.isValid }
    }

    /// Returns the valid signatures in the collection.
    public var validSignatures: [DigitalSignature] {
        signatures.filter { $0.isValid }
    }

    /// Returns the invalid signatures in the collection.
    public var invalidSignatures: [DigitalSignature] {
        signatures.filter { !$0.isValid }
    }
}
