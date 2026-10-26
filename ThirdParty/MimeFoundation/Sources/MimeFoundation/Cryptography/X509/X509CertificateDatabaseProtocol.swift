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
// X509CertificateDatabaseProtocol.swift
//
// Protocol defining certificate database operations.
//

import Foundation
@_spi(CMS) import X509

/// Protocol defining operations for a certificate database.
///
/// Implementations of this protocol provide persistent storage for X.509
/// certificates and their associated metadata. The database can be used
/// to look up certificates by email address, fingerprint, or other criteria.
///
/// ## Implementing a Custom Database
///
/// To implement a custom certificate database:
///
/// 1. Conform to `X509CertificateDatabaseProtocol`
/// 2. Implement all required methods for finding, adding, updating, and removing records
/// 3. Ensure thread-safety for concurrent access
///
/// ## Usage
///
/// ```swift
/// let database: X509CertificateDatabaseProtocol = SqliteCertificateDatabase(path: "/path/to/db")
///
/// // Find certificates for an email address
/// let certs = database.findCertificates(forEmail: "user@example.com", now: Date())
///
/// // Add a new certificate
/// let record = X509CertificateRecord(certificate: cert)
/// database.add(record)
/// ```
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public protocol X509CertificateDatabaseProtocol: Sendable {
    /// Finds a certificate record by certificate.
    ///
    /// The lookup is performed using the certificate's SHA-256 fingerprint.
    ///
    /// - Parameter certificate: The certificate to find.
    /// - Returns: The matching record, or `nil` if not found.
    func find(_ certificate: Certificate) -> X509CertificateRecord?

    /// Finds a certificate record by SHA-256 fingerprint.
    ///
    /// - Parameter fingerprint: The lowercase hex fingerprint.
    /// - Returns: The matching record, or `nil` if not found.
    func find(fingerprint: String) -> X509CertificateRecord?

    /// Finds certificates for an email address.
    ///
    /// This method returns certificates that:
    /// - Have the specified email in their Subject or SAN
    /// - Are currently valid (not expired, not before validity period)
    /// - Optionally have an associated private key
    ///
    /// - Parameters:
    ///   - email: The email address to search for.
    ///   - now: The current date for validity checking.
    ///   - requirePrivateKey: If true, only return certificates with private keys.
    /// - Returns: Matching certificate records.
    func findCertificates(forEmail email: String, now: Date, requirePrivateKey: Bool) -> [X509CertificateRecord]

    /// Finds all trusted anchor (root CA) certificates.
    ///
    /// - Returns: Records for all trusted anchor certificates.
    func findTrustedAnchors() -> [X509CertificateRecord]

    /// Finds certificates matching custom criteria.
    ///
    /// - Parameter predicate: A closure that returns `true` for matching records.
    /// - Returns: Matching certificate records.
    func find(where predicate: @Sendable (X509CertificateRecord) -> Bool) -> [X509CertificateRecord]

    /// Adds a certificate record to the database.
    ///
    /// If a record with the same fingerprint already exists, this method
    /// should do nothing or throw an error, depending on implementation.
    ///
    /// - Parameter record: The record to add.
    /// - Throws: If the record cannot be added.
    func add(_ record: X509CertificateRecord) throws

    /// Updates an existing certificate record.
    ///
    /// The record is identified by its fingerprint. If no matching record
    /// exists, this method should throw an error.
    ///
    /// - Parameter record: The record to update.
    /// - Throws: If the record cannot be updated or doesn't exist.
    func update(_ record: X509CertificateRecord) throws

    /// Removes a certificate record from the database.
    ///
    /// - Parameter record: The record to remove.
    /// - Returns: `true` if the record was removed, `false` if not found.
    @discardableResult
    func remove(_ record: X509CertificateRecord) throws -> Bool

    /// Removes a certificate from the database.
    ///
    /// - Parameter certificate: The certificate to remove.
    /// - Returns: `true` if the certificate was removed, `false` if not found.
    @discardableResult
    func remove(_ certificate: Certificate) throws -> Bool

    /// Returns all certificate records in the database.
    ///
    /// - Returns: All certificate records.
    func allRecords() -> [X509CertificateRecord]

    /// Returns the total number of certificates in the database.
    var count: Int { get }
}

// MARK: - Default Implementations

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public extension X509CertificateDatabaseProtocol {
    /// Finds a certificate record by certificate using its fingerprint.
    func find(_ certificate: Certificate) -> X509CertificateRecord? {
        return find(fingerprint: certificate.sha256Fingerprint)
    }

    /// Removes a certificate from the database.
    @discardableResult
    func remove(_ certificate: Certificate) throws -> Bool {
        guard let record = find(certificate) else {
            return false
        }
        return try remove(record)
    }

    /// Finds certificates for encryption (with private key).
    ///
    /// This is a convenience method for finding certificates that can be used
    /// for decryption or signing.
    ///
    /// - Parameters:
    ///   - email: The email address.
    ///   - now: The current date.
    /// - Returns: Certificates with private keys for the email address.
    func findEncryptionCertificates(forEmail email: String, now: Date = Date()) -> [X509CertificateRecord] {
        return findCertificates(forEmail: email, now: now, requirePrivateKey: true)
    }

    /// Finds certificates for verification (any certificate, with or without private key).
    ///
    /// - Parameters:
    ///   - email: The email address.
    ///   - now: The current date.
    /// - Returns: All valid certificates for the email address.
    func findVerificationCertificates(forEmail email: String, now: Date = Date()) -> [X509CertificateRecord] {
        return findCertificates(forEmail: email, now: now, requirePrivateKey: false)
    }

    /// Creates a `CertificateStore` from the trusted anchors for chain validation.
    ///
    /// - Returns: A `CertificateStore` containing all trusted root certificates.
    func trustedAnchorStore() -> CertificateStore {
        let anchors = findTrustedAnchors()
        return CertificateStore(anchors.map { $0.certificate })
    }
}
