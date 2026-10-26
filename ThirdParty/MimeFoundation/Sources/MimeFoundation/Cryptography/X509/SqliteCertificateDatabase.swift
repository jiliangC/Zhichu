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
// SqliteCertificateDatabase.swift
//
// SQLite implementation of the certificate database.
//

import Foundation
@_spi(CMS) import X509
import SQLite3
import SwiftASN1

/// SQLite-based certificate database for persistent storage.
///
/// This class provides a SQLite implementation of `X509CertificateDatabaseProtocol`
/// for storing X.509 certificates and their metadata. Private keys are encrypted
/// at rest using password-based encryption.
///
/// ## Usage
///
/// ```swift
/// // Create a file-based database
/// let database = try SqliteCertificateDatabase(path: "/path/to/certs.db", password: "secret")
///
/// // Or create an in-memory database for testing
/// let testDb = try SqliteCertificateDatabase(inMemory: true, password: "test")
///
/// // Use the database
/// let record = X509CertificateRecord(certificate: cert, privateKey: key)
/// try database.add(record)
/// ```
///
/// ## Database Schema
///
/// The database uses a single `CERTIFICATES` table with columns for:
/// - Certificate metadata (subject, issuer, fingerprint, etc.)
/// - Trust and CA status
/// - Key usage flags
/// - Validity period
/// - S/MIME capabilities
/// - DER-encoded certificate
/// - Encrypted private key (if present)
///
/// ## Thread Safety
///
/// All database operations are serialized using a lock to ensure thread safety.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public final class SqliteCertificateDatabase: X509CertificateDatabaseProtocol, @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let password: String

    /// Creates a file-based certificate database.
    ///
    /// If the database file doesn't exist, it will be created with the appropriate schema.
    /// If it exists, the schema will be migrated if necessary.
    ///
    /// - Parameters:
    ///   - path: The path to the database file.
    ///   - password: The password for encrypting private keys at rest.
    /// - Throws: `SqliteCertificateDatabaseError` if the database cannot be opened.
    public init(path: String, password: String) throws {
        self.password = password

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw SqliteCertificateDatabaseError.openFailed(errorMessage)
        }

        try createSchema()
    }

    /// Creates an in-memory certificate database.
    ///
    /// This is useful for testing or temporary storage. The database
    /// contents are lost when the instance is deallocated.
    ///
    /// - Parameters:
    ///   - inMemory: Must be `true` to create an in-memory database.
    ///   - password: The password for encrypting private keys.
    /// - Throws: `SqliteCertificateDatabaseError` if the database cannot be created.
    public init(inMemory: Bool, password: String) throws {
        guard inMemory else {
            throw SqliteCertificateDatabaseError.openFailed("Use init(path:password:) for file-based databases")
        }

        self.password = password

        guard sqlite3_open(":memory:", &db) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw SqliteCertificateDatabaseError.openFailed(errorMessage)
        }

        try createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createSchema() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS CERTIFICATES (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                TRUSTED INTEGER NOT NULL DEFAULT 0,
                ANCHOR INTEGER NOT NULL DEFAULT 0,
                BASICCONSTRAINTS INTEGER NOT NULL DEFAULT -1,
                KEYUSAGE INTEGER NOT NULL DEFAULT 0,
                NOTBEFORE INTEGER NOT NULL,
                NOTAFTER INTEGER NOT NULL,
                ISSUERNAME TEXT NOT NULL,
                SERIALNUMBER TEXT NOT NULL,
                SUBJECTNAME TEXT NOT NULL,
                SUBJECTKEYIDENTIFIER TEXT,
                SUBJECTEMAIL TEXT,
                SUBJECTDNSNAMES TEXT,
                FINGERPRINT TEXT NOT NULL UNIQUE,
                ALGORITHMS TEXT,
                ALGORITHMSUPDATED INTEGER NOT NULL DEFAULT 0,
                CERTIFICATE BLOB NOT NULL,
                PRIVATEKEY BLOB
            );

            CREATE INDEX IF NOT EXISTS IDX_FINGERPRINT ON CERTIFICATES (FINGERPRINT);
            CREATE INDEX IF NOT EXISTS IDX_SUBJECTEMAIL ON CERTIFICATES (SUBJECTEMAIL);
            CREATE INDEX IF NOT EXISTS IDX_TRUSTED ON CERTIFICATES (TRUSTED);
            CREATE INDEX IF NOT EXISTS IDX_VALIDITY ON CERTIFICATES (NOTBEFORE, NOTAFTER);
            """

        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let error = errorMessage != nil ? String(cString: errorMessage!) : "Unknown error"
            sqlite3_free(errorMessage)
            throw SqliteCertificateDatabaseError.schemaCreationFailed(error)
        }
    }

    // MARK: - Protocol Implementation

    public func find(fingerprint: String) -> X509CertificateRecord? {
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT * FROM CERTIFICATES WHERE FINGERPRINT = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, fingerprint.lowercased(), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        return readRecord(from: stmt)
    }

    public func findCertificates(forEmail email: String, now: Date, requirePrivateKey: Bool) -> [X509CertificateRecord] {
        lock.lock()
        defer { lock.unlock() }

        let nowTimestamp = Int64(now.timeIntervalSince1970)
        var sql = """
            SELECT * FROM CERTIFICATES
            WHERE SUBJECTEMAIL = ?
            AND NOTBEFORE <= ?
            AND NOTAFTER >= ?
            """

        if requirePrivateKey {
            sql += " AND PRIVATEKEY IS NOT NULL"
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, email.lowercased(), -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, nowTimestamp)
        sqlite3_bind_int64(stmt, 3, nowTimestamp)

        var records: [X509CertificateRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = readRecord(from: stmt) {
                records.append(record)
            }
        }

        return records
    }

    public func findTrustedAnchors() -> [X509CertificateRecord] {
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT * FROM CERTIFICATES WHERE TRUSTED = 1 AND ANCHOR = 1"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var records: [X509CertificateRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = readRecord(from: stmt) {
                records.append(record)
            }
        }

        return records
    }

    public func find(where predicate: @Sendable (X509CertificateRecord) -> Bool) -> [X509CertificateRecord] {
        return allRecords().filter(predicate)
    }

    public func add(_ record: X509CertificateRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        // Check if already exists
        if findUnlocked(fingerprint: record.fingerprint) != nil {
            return // Already exists
        }

        let sql = """
            INSERT INTO CERTIFICATES (
                TRUSTED, ANCHOR, BASICCONSTRAINTS, KEYUSAGE,
                NOTBEFORE, NOTAFTER, ISSUERNAME, SERIALNUMBER,
                SUBJECTNAME, SUBJECTKEYIDENTIFIER, SUBJECTEMAIL, SUBJECTDNSNAMES,
                FINGERPRINT, ALGORITHMS, ALGORITHMSUPDATED, CERTIFICATE, PRIVATEKEY
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SqliteCertificateDatabaseError.queryFailed(error)
        }
        defer { sqlite3_finalize(stmt) }

        // Bind values
        sqlite3_bind_int(stmt, 1, record.isTrusted ? 1 : 0)
        sqlite3_bind_int(stmt, 2, record.isAnchor ? 1 : 0)
        sqlite3_bind_int(stmt, 3, Int32(record.basicConstraints))
        sqlite3_bind_int(stmt, 4, Int32(record.keyUsage.rawValue))
        sqlite3_bind_int64(stmt, 5, Int64(record.notBefore.timeIntervalSince1970))
        sqlite3_bind_int64(stmt, 6, Int64(record.notAfter.timeIntervalSince1970))
        sqlite3_bind_text(stmt, 7, record.issuerName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, record.serialNumber, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 9, record.subjectName, -1, SQLITE_TRANSIENT)

        if let ski = record.subjectKeyIdentifierHex {
            sqlite3_bind_text(stmt, 10, ski, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 10)
        }

        if let email = record.subjectEmail {
            sqlite3_bind_text(stmt, 11, email.lowercased(), -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 11)
        }

        let dnsNames = record.subjectDnsNames.joined(separator: ",")
        sqlite3_bind_text(stmt, 12, dnsNames, -1, SQLITE_TRANSIENT)

        sqlite3_bind_text(stmt, 13, record.fingerprint.lowercased(), -1, SQLITE_TRANSIENT)

        if let algorithms = record.algorithms {
            let algString = algorithms.map { $0.rawValue }.joined(separator: ",")
            sqlite3_bind_text(stmt, 14, algString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 14)
        }

        sqlite3_bind_int64(stmt, 15, Int64(record.algorithmsUpdated.timeIntervalSince1970))

        // Serialize certificate
        let certData = try serializeCertificate(record.certificate)
        _ = certData.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, 16, ptr.baseAddress, Int32(certData.count), SQLITE_TRANSIENT)
        }

        // Encrypt and store private key if present
        if let privateKey = record.privateKey {
            let encryptedKey = try PrivateKeyEncryption.encrypt(privateKey: privateKey, password: password)
            _ = encryptedKey.withUnsafeBytes { ptr in
                sqlite3_bind_blob(stmt, 17, ptr.baseAddress, Int32(encryptedKey.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, 17)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SqliteCertificateDatabaseError.queryFailed(error)
        }
    }

    public func update(_ record: X509CertificateRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        let sql = """
            UPDATE CERTIFICATES SET
                TRUSTED = ?,
                ANCHOR = ?,
                ALGORITHMS = ?,
                ALGORITHMSUPDATED = ?,
                PRIVATEKEY = ?
            WHERE FINGERPRINT = ?
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SqliteCertificateDatabaseError.queryFailed(error)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, record.isTrusted ? 1 : 0)
        sqlite3_bind_int(stmt, 2, record.isAnchor ? 1 : 0)

        if let algorithms = record.algorithms {
            let algString = algorithms.map { $0.rawValue }.joined(separator: ",")
            sqlite3_bind_text(stmt, 3, algString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        sqlite3_bind_int64(stmt, 4, Int64(record.algorithmsUpdated.timeIntervalSince1970))

        if let privateKey = record.privateKey {
            let encryptedKey = try PrivateKeyEncryption.encrypt(privateKey: privateKey, password: password)
            _ = encryptedKey.withUnsafeBytes { ptr in
                sqlite3_bind_blob(stmt, 5, ptr.baseAddress, Int32(encryptedKey.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        sqlite3_bind_text(stmt, 6, record.fingerprint.lowercased(), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SqliteCertificateDatabaseError.queryFailed(error)
        }
    }

    @discardableResult
    public func remove(_ record: X509CertificateRecord) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let sql = "DELETE FROM CERTIFICATES WHERE FINGERPRINT = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SqliteCertificateDatabaseError.queryFailed(error)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, record.fingerprint.lowercased(), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let error = String(cString: sqlite3_errmsg(db))
            throw SqliteCertificateDatabaseError.queryFailed(error)
        }

        return sqlite3_changes(db) > 0
    }

    public func allRecords() -> [X509CertificateRecord] {
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT * FROM CERTIFICATES"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var records: [X509CertificateRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = readRecord(from: stmt) {
                records.append(record)
            }
        }

        return records
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT COUNT(*) FROM CERTIFICATES"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Private Helpers

    private func findUnlocked(fingerprint: String) -> X509CertificateRecord? {
        let sql = "SELECT * FROM CERTIFICATES WHERE FINGERPRINT = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, fingerprint.lowercased(), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        return readRecord(from: stmt)
    }

    private func readRecord(from stmt: OpaquePointer?) -> X509CertificateRecord? {
        guard let stmt = stmt else { return nil }

        // Read certificate blob
        guard let certBlobPtr = sqlite3_column_blob(stmt, 16) else {
            return nil
        }
        let certBlobSize = Int(sqlite3_column_bytes(stmt, 16))
        let certData = Data(bytes: certBlobPtr, count: certBlobSize)

        // Parse certificate
        guard let certificate = try? Certificate(derEncoded: Array(certData)) else {
            return nil
        }

        // Read private key if present
        var privateKey: Certificate.PrivateKey? = nil
        if let keyBlobPtr = sqlite3_column_blob(stmt, 17) {
            let keyBlobSize = Int(sqlite3_column_bytes(stmt, 17))
            let encryptedKey = Array(Data(bytes: keyBlobPtr, count: keyBlobSize))
            privateKey = try? PrivateKeyEncryption.decrypt(encryptedKey: encryptedKey, password: password)
        }

        // Read algorithms
        var algorithms: [EncryptionAlgorithm]? = nil
        if let algTextPtr = sqlite3_column_text(stmt, 14) {
            let algString = String(cString: algTextPtr)
            if !algString.isEmpty {
                algorithms = algString.split(separator: ",").compactMap {
                    EncryptionAlgorithm(rawValue: String($0))
                }
            }
        }

        return X509CertificateRecord(
            certificate: certificate,
            privateKey: privateKey,
            isTrusted: sqlite3_column_int(stmt, 1) != 0,
            algorithms: algorithms,
            algorithmsUpdated: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 15))),
            id: Int(sqlite3_column_int64(stmt, 0))
        )
    }

    private func serializeCertificate(_ certificate: Certificate) throws -> [UInt8] {
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        return serializer.serializedBytes
    }
}

// MARK: - Errors

/// Errors that can occur during certificate database operations.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public enum SqliteCertificateDatabaseError: Error, Sendable {
    /// Failed to open the database.
    case openFailed(String)
    /// Failed to create the database schema.
    case schemaCreationFailed(String)
    /// A database query failed.
    case queryFailed(String)
    /// The record was not found.
    case notFound
}

// MARK: - SQLite Constants

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
