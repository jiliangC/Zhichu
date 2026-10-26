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
// X509ChainValidator.swift
//
// Certificate chain validation using swift-certificates.
//

import Foundation
@_spi(CMS) import X509

/// Validates X.509 certificate chains using RFC 5280 rules.
///
/// This struct provides certificate chain validation using swift-certificates'
/// `Verifier` with `RFC5280Policy`. It builds and validates paths from a leaf
/// certificate to a trusted root.
///
/// ## Usage
///
/// ```swift
/// let validator = X509ChainValidator()
///
/// // Create a trust store with root certificates
/// let trustRoots = CertificateStore([rootCert1, rootCert2])
///
/// // Validate a certificate chain
/// let result = await validator.validate(
///     leaf: userCertificate,
///     intermediates: [intermediateCert],
///     trustRoots: trustRoots
/// )
///
/// if result.isValid {
///     print("Certificate is trusted")
/// } else {
///     print("Validation failed: \(result.error!)")
/// }
/// ```
///
/// ## Validation Rules
///
/// The validator checks:
/// - Certificate signatures
/// - Validity periods (not expired, not before validity)
/// - Basic constraints (CA certificates, path length)
/// - Key usage constraints
/// - Name chaining (issuer matches subject of issuing certificate)
/// - Trust anchor (chain must end at a trusted root)
///
/// ## Limitations
///
/// - CRL (Certificate Revocation List) checking is not yet supported
/// - OCSP (Online Certificate Status Protocol) checking is not yet supported
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct X509ChainValidator: Sendable {

    /// Creates a new chain validator.
    public init() {}

    /// Validates a certificate chain.
    ///
    /// This method validates that the leaf certificate can be chained to a
    /// trusted root certificate using the provided intermediates.
    ///
    /// - Parameters:
    ///   - leaf: The end-entity certificate to validate.
    ///   - intermediates: Intermediate certificates that may be needed to build the chain.
    ///   - trustRoots: A certificate store containing trusted root certificates.
    ///   - validationTime: The time to use for validity checking (defaults to now).
    /// - Returns: A `ChainValidationResult` indicating whether validation succeeded.
    public func validate(
        leaf: Certificate,
        intermediates: [Certificate] = [],
        trustRoots: CertificateStore,
        validationTime: Date = Date()
    ) async -> ChainValidationResult {
        // Create a verifier with RFC5280 policy
        var verifier = Verifier(rootCertificates: trustRoots) {
            RFC5280Policy(validationTime: validationTime)
        }

        // Verify the chain
        let result = await verifier.validate(leaf: leaf, intermediates: CertificateStore(intermediates))

        switch result {
        case .validCertificate(let validChain):
            return .success(chain: Array(validChain))
        case .couldNotValidate(let failures):
            // Convert the first failure to our error type
            if let firstFailure = failures.first {
                let error = convertVerificationError(firstFailure, leaf: leaf)
                return .failure(error)
            }
            return .failure(.pathBuildingFailed("Unknown validation failure"))
        }
    }

    /// Validates a certificate against a database of certificates.
    ///
    /// This method looks up trusted anchors and intermediate certificates
    /// from the database to build and validate the chain.
    ///
    /// - Parameters:
    ///   - leaf: The end-entity certificate to validate.
    ///   - database: The certificate database containing trust anchors and intermediates.
    ///   - validationTime: The time to use for validity checking (defaults to now).
    /// - Returns: A `ChainValidationResult` indicating whether validation succeeded.
    public func validate(
        leaf: Certificate,
        database: X509CertificateDatabaseProtocol,
        validationTime: Date = Date()
    ) async -> ChainValidationResult {
        // Get trusted anchors
        let anchors = database.findTrustedAnchors()
        let trustRoots = CertificateStore(anchors.map { $0.certificate })

        // Get all certificates as potential intermediates
        let allRecords = database.allRecords()
        let intermediates = allRecords
            .filter { !$0.isAnchor } // Exclude trust anchors
            .map { $0.certificate }

        return await validate(
            leaf: leaf,
            intermediates: intermediates,
            trustRoots: trustRoots,
            validationTime: validationTime
        )
    }

    /// Validates a certificate store entry.
    ///
    /// - Parameters:
    ///   - store: The certificate store containing the certificate and trust roots.
    ///   - certificate: The certificate to validate.
    ///   - validationTime: The time to use for validity checking.
    /// - Returns: A `ChainValidationResult` indicating whether validation succeeded.
    public func validate(
        store: X509CertificateStore,
        certificate: Certificate,
        validationTime: Date = Date()
    ) async -> ChainValidationResult {
        let trustRoots = store.asCertificateStore()
        let intermediates = store.certificates.filter { $0.sha256Fingerprint != certificate.sha256Fingerprint }

        return await validate(
            leaf: certificate,
            intermediates: intermediates,
            trustRoots: trustRoots,
            validationTime: validationTime
        )
    }

    // MARK: - Error Conversion

    private func convertVerificationError(
        _ failure: CertificateValidationResult.PolicyFailure,
        leaf: Certificate
    ) -> ChainValidationError {
        let certName = leaf.subjectString

        // Get the policy failure reason description
        let reasonDescription = String(describing: failure.policyFailureReason)

        if reasonDescription.contains("expired") || reasonDescription.contains("notAfter") {
            return .expired(certificate: certName, expiredAt: leaf.notValidAfter)
        } else if reasonDescription.contains("notBefore") || reasonDescription.contains("not yet valid") {
            return .notYetValid(certificate: certName, validFrom: leaf.notValidBefore)
        } else if reasonDescription.contains("signature") {
            return .invalidSignature(certificate: certName, reason: reasonDescription)
        } else if reasonDescription.contains("trust") || reasonDescription.contains("anchor") || reasonDescription.contains("root") {
            return .noTrustAnchor
        } else if reasonDescription.contains("keyUsage") || reasonDescription.contains("key usage") {
            return .invalidKeyUsage(certificate: certName, requiredUsage: reasonDescription)
        } else if reasonDescription.contains("basicConstraints") || reasonDescription.contains("path") {
            return .invalidExtension(certificate: certName, extension: "basicConstraints", reason: reasonDescription)
        } else {
            return .pathBuildingFailed(reasonDescription)
        }
    }
}

// MARK: - Convenience Extensions

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public extension X509ChainValidator {
    /// Validates that a certificate is currently valid (not expired).
    ///
    /// This is a quick check that only validates the certificate's validity period,
    /// without performing full chain validation.
    ///
    /// - Parameters:
    ///   - certificate: The certificate to check.
    ///   - at: The time to check validity for (defaults to now).
    /// - Returns: `true` if the certificate is within its validity period.
    static func isCurrentlyValid(_ certificate: Certificate, at date: Date = Date()) -> Bool {
        return date >= certificate.notValidBefore && date <= certificate.notValidAfter
    }

    /// Checks whether a certificate is self-signed.
    ///
    /// A certificate is self-signed if its subject and issuer are identical.
    /// Note that this does not verify the signature.
    ///
    /// - Parameter certificate: The certificate to check.
    /// - Returns: `true` if the certificate is self-signed.
    static func isSelfSigned(_ certificate: Certificate) -> Bool {
        return certificate.isSelfSigned
    }
}
