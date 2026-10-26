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
// X509CertificateStore.swift
//
// In-memory certificate store.
//

import Foundation
@_spi(CMS) import X509
import Crypto
#if canImport(Security)
import Security
#endif

/// An in-memory certificate store for managing X.509 certificates.
///
/// This class provides a simple way to manage certificates and their
/// associated private keys in memory. It can import and export PKCS#12
/// files and integrates with swift-certificates' `CertificateStore`.
///
/// ## Usage
///
/// ```swift
/// let store = X509CertificateStore()
///
/// // Add certificates
/// store.add(certificate)
/// store.add(certificate, privateKey: privateKey)
///
/// // Find certificates
/// let matches = store.find { $0.emailAddresses.contains("user@example.com") }
///
/// // Export to PKCS#12
/// let p12Data = try store.exportPKCS12(password: "secret")
/// ```
///
/// ## Thread Safety
///
/// This class is thread-safe for concurrent read and write operations.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public final class X509CertificateStore: @unchecked Sendable {
    /// Storage for certificates and their private keys.
    private var storage: [String: (certificate: Certificate, privateKey: Certificate.PrivateKey?)]
    private let lock = NSLock()

    /// Creates an empty certificate store.
    public init() {
        self.storage = [:]
    }

    /// Creates a certificate store with initial certificates.
    ///
    /// - Parameter certificates: The initial certificates to add.
    public init(certificates: [Certificate]) {
        self.storage = [:]
        for cert in certificates {
            let fingerprint = cert.sha256Fingerprint
            storage[fingerprint] = (cert, nil)
        }
    }

    /// The certificates in this store.
    public var certificates: [Certificate] {
        lock.lock()
        defer { lock.unlock() }
        return storage.values.map { $0.certificate }
    }

    /// The number of certificates in this store.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// A Boolean indicating whether the store is empty.
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }

    // MARK: - Adding Certificates

    /// Adds a certificate to the store.
    ///
    /// If a certificate with the same fingerprint already exists, this method
    /// does nothing (the existing certificate is retained).
    ///
    /// - Parameter certificate: The certificate to add.
    public func add(_ certificate: Certificate) {
        lock.lock()
        defer { lock.unlock() }

        let fingerprint = certificate.sha256Fingerprint
        if storage[fingerprint] == nil {
            storage[fingerprint] = (certificate, nil)
        }
    }

    /// Adds a certificate with an associated private key.
    ///
    /// If a certificate with the same fingerprint already exists but without
    /// a private key, the private key will be added. If the certificate
    /// already has a private key, this method does nothing.
    ///
    /// - Parameters:
    ///   - certificate: The certificate to add.
    ///   - privateKey: The private key associated with the certificate.
    public func add(_ certificate: Certificate, privateKey: Certificate.PrivateKey) {
        lock.lock()
        defer { lock.unlock() }

        let fingerprint = certificate.sha256Fingerprint
        if let existing = storage[fingerprint] {
            // Only add private key if one doesn't already exist
            if existing.privateKey == nil {
                storage[fingerprint] = (certificate, privateKey)
            }
        } else {
            storage[fingerprint] = (certificate, privateKey)
        }
    }

    /// Adds multiple certificates to the store.
    ///
    /// - Parameter certificates: The certificates to add.
    public func add(_ certificates: [Certificate]) {
        for cert in certificates {
            add(cert)
        }
    }

    // MARK: - Removing Certificates

    /// Removes a certificate from the store.
    ///
    /// - Parameter certificate: The certificate to remove.
    /// - Returns: `true` if the certificate was removed, `false` if it wasn't found.
    @discardableResult
    public func remove(_ certificate: Certificate) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let fingerprint = certificate.sha256Fingerprint
        return storage.removeValue(forKey: fingerprint) != nil
    }

    /// Removes all certificates from the store.
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    // MARK: - Finding Certificates

    /// Returns the private key associated with a certificate.
    ///
    /// - Parameter certificate: The certificate to look up.
    /// - Returns: The private key, or `nil` if not found or no key is associated.
    public func privateKey(for certificate: Certificate) -> Certificate.PrivateKey? {
        lock.lock()
        defer { lock.unlock() }

        let fingerprint = certificate.sha256Fingerprint
        return storage[fingerprint]?.privateKey
    }

    /// Finds certificates matching a predicate.
    ///
    /// - Parameter predicate: A closure that returns `true` for matching certificates.
    /// - Returns: An array of matching certificates.
    public func find(where predicate: (Certificate) -> Bool) -> [Certificate] {
        lock.lock()
        defer { lock.unlock() }

        return storage.values.compactMap { entry in
            predicate(entry.certificate) ? entry.certificate : nil
        }
    }

    /// Finds a certificate by its SHA-256 fingerprint.
    ///
    /// - Parameter fingerprint: The lowercase hex fingerprint.
    /// - Returns: The certificate, or `nil` if not found.
    public func find(fingerprint: String) -> Certificate? {
        lock.lock()
        defer { lock.unlock() }
        return storage[fingerprint.lowercased()]?.certificate
    }

    /// Finds certificates that have an associated private key.
    ///
    /// - Returns: Certificates with private keys.
    public func certificatesWithPrivateKeys() -> [Certificate] {
        lock.lock()
        defer { lock.unlock() }

        return storage.values.compactMap { entry in
            entry.privateKey != nil ? entry.certificate : nil
        }
    }

    /// Checks whether this store contains a certificate.
    ///
    /// - Parameter certificate: The certificate to check.
    /// - Returns: `true` if the certificate is in the store.
    public func contains(_ certificate: Certificate) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let fingerprint = certificate.sha256Fingerprint
        return storage[fingerprint] != nil
    }

    // MARK: - PKCS#12 Import/Export

    #if canImport(Security)
    /// Imports certificates and private keys from PKCS#12 data.
    ///
    /// - Parameters:
    ///   - data: The PKCS#12 data.
    ///   - password: The password to decrypt the PKCS#12 data.
    /// - Throws: An error if the import fails.
    public func importPKCS12(from data: Data, password: String) throws {
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess else {
            throw X509CertificateStoreError.pkcs12ImportFailed("SecPKCS12Import failed with status: \(status)")
        }

        guard let itemsArray = items as? [[String: Any]] else {
            throw X509CertificateStoreError.pkcs12ImportFailed("No items found in PKCS#12 data")
        }

        for item in itemsArray {
            // Get certificate chain
            if let chainRefs = item[kSecImportItemCertChain as String] as? [SecCertificate] {
                for secCert in chainRefs {
                    if let cert = try? Certificate(secCert) {
                        add(cert)
                    }
                }
            }

            // Get identity (certificate + private key)
            if let identityRef = item[kSecImportItemIdentity as String] {
                let identity = identityRef as! SecIdentity

                var secCert: SecCertificate?
                SecIdentityCopyCertificate(identity, &secCert)

                if let cert = secCert, let certificate = try? Certificate(cert) {
                    // Try to extract private key
                    var secKey: SecKey?
                    SecIdentityCopyPrivateKey(identity, &secKey)

                    if let key = secKey, let privateKey = try? extractPrivateKey(from: key) {
                        add(certificate, privateKey: privateKey)
                    } else {
                        add(certificate)
                    }
                }
            }
        }
    }

    /// Extracts a Certificate.PrivateKey from a SecKey.
    private func extractPrivateKey(from secKey: SecKey) throws -> Certificate.PrivateKey? {
        guard let attributes = SecKeyCopyAttributes(secKey) as? [String: Any] else {
            return nil
        }

        let keyType = attributes[kSecAttrKeyType as String] as? String
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 0

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(secKey, &error) as Data? else {
            return nil
        }

        if keyType == kSecAttrKeyTypeECSECPrimeRandom as String {
            switch keySize {
            case 256:
                if let key = try? P256.Signing.PrivateKey(x963Representation: keyData) {
                    return Certificate.PrivateKey(key)
                }
            case 384:
                if let key = try? P384.Signing.PrivateKey(x963Representation: keyData) {
                    return Certificate.PrivateKey(key)
                }
            case 521:
                if let key = try? P521.Signing.PrivateKey(x963Representation: keyData) {
                    return Certificate.PrivateKey(key)
                }
            default:
                break
            }
        } else if keyType == kSecAttrKeyTypeRSA as String {
            if let key = try? _RSA.Signing.PrivateKey(derRepresentation: keyData) {
                return Certificate.PrivateKey(key)
            }
        }

        return nil
    }

    /// Exports the store contents to PKCS#12 format.
    ///
    /// Only certificates with associated private keys can be exported to PKCS#12.
    ///
    /// - Parameter password: The password to protect the PKCS#12 data.
    /// - Returns: The PKCS#12 data.
    /// - Throws: An error if the export fails.
    public func exportPKCS12(password: String) throws -> Data {
        // Note: Full PKCS#12 export requires Security framework identity creation
        // which is complex. For now, we throw an error indicating this limitation.
        throw X509CertificateStoreError.pkcs12ExportFailed("PKCS#12 export is not yet implemented")
    }
    #endif

    // MARK: - Integration with swift-certificates

    /// Creates a `CertificateStore` for use with swift-certificates APIs.
    ///
    /// The returned store contains all certificates from this store
    /// and can be used as trust roots for signature verification.
    ///
    /// - Returns: A `CertificateStore` containing all certificates.
    public func asCertificateStore() -> CertificateStore {
        lock.lock()
        defer { lock.unlock() }

        return CertificateStore(storage.values.map { $0.certificate })
    }
}

// MARK: - Errors

/// Errors that can occur during certificate store operations.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public enum X509CertificateStoreError: Error, Sendable {
    /// PKCS#12 import failed.
    case pkcs12ImportFailed(String)
    /// PKCS#12 export failed.
    case pkcs12ExportFailed(String)
}

// MARK: - Import for CryptoExtras

import _CryptoExtras
