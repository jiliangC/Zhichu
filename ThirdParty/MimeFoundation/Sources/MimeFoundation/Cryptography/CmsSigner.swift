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
// CmsSigner.swift
//
// CMS signer for S/MIME signing operations.
//

import Foundation
@_spi(CMS) import X509
#if canImport(Security)
import Security
#endif
import Crypto
import _CryptoExtras

/// An S/MIME signer for CMS (Cryptographic Message Syntax) operations.
///
/// If the X.509 certificate is known for the signer, you may wish to use a
/// ``CmsSigner`` as opposed to having the ``SecureMimeContext`` do its own
/// certificate lookup.
///
/// A ``CmsSigner`` wraps a certificate and its associated private key, along
/// with configuration options for signing operations.
///
/// ## Usage
///
/// ```swift
/// // Create a signer from PEM files
/// let signer = try CmsSigner(
///     certificatePath: "/path/to/cert.pem",
///     privateKeyPath: "/path/to/key.pem"
/// )
///
/// // Create a signed message
/// let context = SecureMimeContext()
/// let signedMessage = try MultipartSigned.create(entity, signer: signer, context: context)
/// ```
///
/// ## Topics
///
/// ### Creating a Signer
/// - ``init(certificate:privateKey:certificateChain:digestAlgorithm:)``
/// - ``init(certificatePEM:privateKeyPEM:certificateChain:digestAlgorithm:)``
/// - ``init(certificateDER:privateKeyDER:certificateChain:digestAlgorithm:)``
/// - ``init(certificatePath:privateKeyPath:certificateChain:digestAlgorithm:)``
/// - ``init(pkcs12Data:password:digestAlgorithm:)``
/// - ``init(pkcs12Path:password:digestAlgorithm:)``
///
/// ### Properties
/// - ``certificate``
/// - ``privateKey``
/// - ``certificateChain``
/// - ``digestAlgorithm``
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct CmsSigner: Sendable {
    /// The signer's certificate.
    ///
    /// The signer's certificate contains a public key that can be used for
    /// verifying the digital signature.
    public let certificate: Certificate

    /// The signer's private key.
    ///
    /// The private key is used for generating digital signatures.
    public let privateKey: Certificate.PrivateKey

    /// The certificate chain.
    ///
    /// Additional intermediate certificates to include in the signature.
    /// These certificates help recipients build a chain of trust from the
    /// signer's certificate to a trusted root certificate.
    public var certificateChain: [Certificate]

    /// The digest algorithm to use for signing.
    ///
    /// Specifies which digest algorithm to use to generate the cryptographic
    /// hash of the content being signed. The default is ``DigestAlgorithm/sha256``.
    public var digestAlgorithm: DigestAlgorithm

    /// Creates a new CMS signer with a certificate and private key.
    ///
    /// The initial value of ``digestAlgorithm`` will be set to
    /// ``DigestAlgorithm/sha256``.
    ///
    /// - Parameters:
    ///   - certificate: The certificate to use for signing.
    ///   - privateKey: The private key corresponding to the certificate.
    ///   - certificateChain: Additional intermediate certificates to include.
    ///     Defaults to an empty array.
    ///   - digestAlgorithm: The digest algorithm to use. Defaults to
    ///     ``DigestAlgorithm/sha256``.
    public init(
        certificate: Certificate,
        privateKey: Certificate.PrivateKey,
        certificateChain: [Certificate] = [],
        digestAlgorithm: DigestAlgorithm = .sha256
    ) {
        self.certificate = certificate
        self.privateKey = privateKey
        self.certificateChain = certificateChain
        self.digestAlgorithm = digestAlgorithm
    }

    /// Creates a CMS signer from PEM-encoded certificate and private key data.
    ///
    /// The initial value of ``digestAlgorithm`` will be set to
    /// ``DigestAlgorithm/sha256``.
    ///
    /// - Parameters:
    ///   - certificatePEM: The PEM-encoded certificate string.
    ///   - privateKeyPEM: The PEM-encoded private key string.
    ///   - certificateChain: Additional intermediate certificates.
    ///   - digestAlgorithm: The digest algorithm to use. Defaults to SHA-256.
    /// - Throws: ``SecureMimeError/invalidCertificate(_:)`` if the certificate
    ///   cannot be parsed, or ``SecureMimeError/invalidPrivateKey(_:)`` if the
    ///   key cannot be parsed.
    public init(
        certificatePEM: String,
        privateKeyPEM: String,
        certificateChain: [Certificate] = [],
        digestAlgorithm: DigestAlgorithm = .sha256
    ) throws {
        do {
            self.certificate = try Certificate(pemEncoded: certificatePEM)
        } catch {
            throw SecureMimeError.invalidCertificate(String(describing: error))
        }

        do {
            self.privateKey = try Certificate.PrivateKey(pemEncoded: privateKeyPEM)
        } catch {
            throw SecureMimeError.invalidPrivateKey(String(describing: error))
        }

        self.certificateChain = certificateChain
        self.digestAlgorithm = digestAlgorithm
    }

    /// Creates a CMS signer from DER-encoded certificate and private key data.
    ///
    /// The initial value of ``digestAlgorithm`` will be set to
    /// ``DigestAlgorithm/sha256``.
    ///
    /// - Parameters:
    ///   - certificateDER: The DER-encoded certificate bytes.
    ///   - privateKeyDER: The DER-encoded private key bytes (PKCS#8 format).
    ///   - certificateChain: Additional intermediate certificates.
    ///   - digestAlgorithm: The digest algorithm to use. Defaults to SHA-256.
    /// - Throws: ``SecureMimeError/invalidCertificate(_:)`` if the certificate
    ///   cannot be parsed, or ``SecureMimeError/invalidPrivateKey(_:)`` if the
    ///   key cannot be parsed.
    public init(
        certificateDER: [UInt8],
        privateKeyDER: [UInt8],
        certificateChain: [Certificate] = [],
        digestAlgorithm: DigestAlgorithm = .sha256
    ) throws {
        do {
            self.certificate = try Certificate(derEncoded: certificateDER)
        } catch {
            throw SecureMimeError.invalidCertificate(String(describing: error))
        }

        do {
            self.privateKey = try Certificate.PrivateKey(derBytes: privateKeyDER)
        } catch {
            throw SecureMimeError.invalidPrivateKey(String(describing: error))
        }

        self.certificateChain = certificateChain
        self.digestAlgorithm = digestAlgorithm
    }

    /// Creates a CMS signer by loading a certificate and private key from files.
    ///
    /// The initial value of ``digestAlgorithm`` will be set to
    /// ``DigestAlgorithm/sha256``.
    ///
    /// - Parameters:
    ///   - certificatePath: Path to the PEM-encoded certificate file.
    ///   - privateKeyPath: Path to the PEM-encoded private key file.
    ///   - certificateChain: Additional intermediate certificates.
    ///   - digestAlgorithm: The digest algorithm to use. Defaults to SHA-256.
    /// - Throws: ``SecureMimeError/fileReadFailed(_:)`` if the files cannot be read,
    ///   ``SecureMimeError/invalidCertificate(_:)`` if the certificate cannot be
    ///   parsed, or ``SecureMimeError/invalidPrivateKey(_:)`` if the key cannot
    ///   be parsed.
    public init(
        certificatePath: String,
        privateKeyPath: String,
        certificateChain: [Certificate] = [],
        digestAlgorithm: DigestAlgorithm = .sha256
    ) throws {
        let certData: Data
        let keyData: Data

        do {
            certData = try Data(contentsOf: URL(fileURLWithPath: certificatePath))
        } catch {
            throw SecureMimeError.fileReadFailed("Failed to read certificate file: \(error.localizedDescription)")
        }

        do {
            keyData = try Data(contentsOf: URL(fileURLWithPath: privateKeyPath))
        } catch {
            throw SecureMimeError.fileReadFailed("Failed to read private key file: \(error.localizedDescription)")
        }

        guard let certPEM = String(data: certData, encoding: .utf8) else {
            throw SecureMimeError.invalidCertificate("Certificate file is not valid UTF-8")
        }

        guard let keyPEM = String(data: keyData, encoding: .utf8) else {
            throw SecureMimeError.invalidPrivateKey("Private key file is not valid UTF-8")
        }

        try self.init(
            certificatePEM: certPEM,
            privateKeyPEM: keyPEM,
            certificateChain: certificateChain,
            digestAlgorithm: digestAlgorithm
        )
    }

    #if canImport(Security)
    /// Creates a CMS signer from PKCS#12 data.
    ///
    /// PKCS#12 (also known as PFX) is a binary format for storing a certificate
    /// and its private key together, protected by a password.
    ///
    /// The initial value of ``digestAlgorithm`` will be set to
    /// ``DigestAlgorithm/sha256``.
    ///
    /// - Parameters:
    ///   - pkcs12Data: The PKCS#12 data.
    ///   - password: The password to decrypt the PKCS#12 data.
    ///   - digestAlgorithm: The digest algorithm to use. Defaults to SHA-256.
    /// - Throws: ``SecureMimeError/pkcs12LoadFailed(_:)`` if the PKCS#12 data
    ///   cannot be loaded, ``SecureMimeError/invalidCertificate(_:)`` if the
    ///   certificate cannot be converted, or ``SecureMimeError/invalidPrivateKey(_:)``
    ///   if the key cannot be converted.
    ///
    /// - Note: This initializer is only available on Apple platforms.
    ///
    /// - Important: Due to key format incompatibilities between Apple's Security framework
    ///   and swift-crypto, this initializer may fail to convert the private key. If you
    ///   encounter this issue, convert your PKCS#12 to PEM format using OpenSSL:
    ///   ```bash
    ///   openssl pkcs12 -in file.p12 -nocerts -nodes -out key.pem
    ///   openssl pkcs12 -in file.p12 -clcerts -nokeys -out cert.pem
    ///   ```
    ///   Then use ``init(certificatePath:privateKeyPath:certificateChain:digestAlgorithm:)``
    ///   instead.
    public init(
        pkcs12Data: Data,
        password: String,
        digestAlgorithm: DigestAlgorithm = .sha256
    ) throws {
        // Import the PKCS#12 data using SecPKCS12Import
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(pkcs12Data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess else {
            throw SecureMimeError.pkcs12LoadFailed("SecPKCS12Import failed with status: \(status)")
        }

        guard let itemsArray = items as? [[String: Any]], !itemsArray.isEmpty else {
            throw SecureMimeError.pkcs12LoadFailed("No items found in PKCS#12 data")
        }

        // Get the first identity
        guard let identityRef = itemsArray[0][kSecImportItemIdentity as String] else {
            throw SecureMimeError.pkcs12LoadFailed("No identity found in PKCS#12 data")
        }

        let identity = identityRef as! SecIdentity

        // Extract certificate from identity
        var secCertificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &secCertificate)
        guard certStatus == errSecSuccess, let cert = secCertificate else {
            throw SecureMimeError.pkcs12LoadFailed("Failed to extract certificate from identity")
        }

        // Convert SecCertificate to swift-certificates Certificate
        do {
            self.certificate = try Certificate(cert)
        } catch {
            throw SecureMimeError.invalidCertificate("Failed to convert certificate: \(error)")
        }

        // Extract private key from identity
        var secKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &secKey)
        guard keyStatus == errSecSuccess, let privateKeyRef = secKey else {
            throw SecureMimeError.pkcs12LoadFailed("Failed to extract private key from identity")
        }

        // Convert SecKey to swift-certificates Certificate.PrivateKey using SecItemExport
        self.privateKey = try Self.exportSecKeyToPrivateKey(privateKeyRef, password: password)

        // Extract certificate chain if present
        if let chainRefs = itemsArray[0][kSecImportItemCertChain as String] as? [SecCertificate] {
            var chain: [Certificate] = []
            for chainCert in chainRefs {
                // Skip the end-entity certificate (it's the same as self.certificate)
                let chainCertData = SecCertificateCopyData(chainCert) as Data
                let selfCertData = SecCertificateCopyData(cert) as Data
                if chainCertData != selfCertData {
                    if let converted = try? Certificate(chainCert) {
                        chain.append(converted)
                    }
                }
            }
            self.certificateChain = chain
        } else {
            self.certificateChain = []
        }

        self.digestAlgorithm = digestAlgorithm
    }

    /// Creates a CMS signer from a PKCS#12 file.
    ///
    /// The initial value of ``digestAlgorithm`` will be set to
    /// ``DigestAlgorithm/sha256``.
    ///
    /// - Parameters:
    ///   - pkcs12Path: Path to the PKCS#12 file (.p12 or .pfx).
    ///   - password: The password to decrypt the PKCS#12 file.
    ///   - digestAlgorithm: The digest algorithm to use. Defaults to SHA-256.
    /// - Throws: ``SecureMimeError/fileReadFailed(_:)`` if the file cannot be read,
    ///   or other ``SecureMimeError`` cases if the PKCS#12 content cannot be parsed.
    ///
    /// - Note: This initializer is only available on Apple platforms.
    public init(
        pkcs12Path: String,
        password: String,
        digestAlgorithm: DigestAlgorithm = .sha256
    ) throws {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: pkcs12Path))
        } catch {
            throw SecureMimeError.fileReadFailed("Failed to read PKCS#12 file: \(error.localizedDescription)")
        }

        try self.init(
            pkcs12Data: data,
            password: password,
            digestAlgorithm: digestAlgorithm
        )
    }

    /// Exports a SecKey to a Certificate.PrivateKey.
    ///
    /// This method attempts multiple export formats to find one that swift-crypto can parse.
    private static func exportSecKeyToPrivateKey(_ secKey: SecKey, password: String) throws -> Certificate.PrivateKey {
        // Get the key type and size
        guard let attributes = SecKeyCopyAttributes(secKey) as? [String: Any] else {
            throw SecureMimeError.invalidPrivateKey("Failed to get key attributes")
        }

        let keyType = attributes[kSecAttrKeyType as String] as? String
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 0

#if os(macOS)
        // Try exporting to PEM format (PKCS#8 wrapped with PEM armor)
        var exportedData: CFData?
        var exportStatus = SecItemExport(
            secKey,
            .formatPEMSequence,
            .pemArmour,
            nil,
            &exportedData
        )

        if exportStatus == errSecSuccess, let pemData = exportedData as Data?,
           let pemString = String(data: pemData, encoding: .utf8) {
            // Try parsing as PEM
            if let privateKey = try? Certificate.PrivateKey(pemEncoded: pemString) {
                return privateKey
            }
        }

        // Try BSAFE format (PKCS#8 DER)
        exportStatus = SecItemExport(
            secKey,
            .formatBSAFE,
            [],
            nil,
            &exportedData
        )

        if exportStatus == errSecSuccess, let data = exportedData as Data? {
            // Try to parse as PKCS#8 DER
            if let privateKey = try? Certificate.PrivateKey(derBytes: Array(data)) {
                return privateKey
            }
        }

        // Try OpenSSL format (SEC1 for EC, PKCS#1 for RSA)
        exportStatus = SecItemExport(
            secKey,
            .formatOpenSSL,
            [],
            nil,
            &exportedData
        )

        if exportStatus == errSecSuccess, let data = exportedData as Data? {
            // Try to parse the data based on key type
            if let privateKey = try? convertKeyData(data, keyType: keyType, keySize: keySize) {
                return privateKey
            }
        }
#endif
        
        // Try SecKeyCopyExternalRepresentation (raw format)
        var error: Unmanaged<CFError>?
        if let keyData = SecKeyCopyExternalRepresentation(secKey, &error) as Data? {
            if let privateKey = try? convertKeyData(keyData, keyType: keyType, keySize: keySize) {
                return privateKey
            }
        }

        // If all exports fail, throw a descriptive error
        throw SecureMimeError.invalidPrivateKey(
            "Cannot convert private key from PKCS#12 to swift-crypto format. " +
            "To use PKCS#12 credentials, extract the key to PEM format using: " +
            "openssl pkcs12 -in file.p12 -nocerts -nodes -out key.pem"
        )
    }

    /// Converts raw key data to a Certificate.PrivateKey based on key type.
    private static func convertKeyData(_ keyData: Data, keyType: String?, keySize: Int) throws -> Certificate.PrivateKey {
        // Convert based on key type
        if keyType == kSecAttrKeyTypeRSA as String {
            // RSA key - try PKCS#1 format
            let rsaKey = try _RSA.Signing.PrivateKey(derRepresentation: keyData)
            return Certificate.PrivateKey(rsaKey)
        } else if keyType == kSecAttrKeyTypeECSECPrimeRandom as String {
            // EC key - SecKeyCopyExternalRepresentation returns X9.63 format:
            // 04 || X || Y || K for private keys
            // Where K is the private scalar at the end
            return try convertECKeyData(keyData, keySize: keySize)
        } else {
            throw SecureMimeError.invalidPrivateKey("Unsupported key type: \(keyType ?? "unknown")")
        }
    }

    /// Converts EC key data from Security framework format to swift-crypto.
    private static func convertECKeyData(_ keyData: Data, keySize: Int) throws -> Certificate.PrivateKey {
        // Calculate expected sizes
        let scalarSize: Int
        switch keySize {
        case 256: scalarSize = 32
        case 384: scalarSize = 48
        case 521: scalarSize = 66  // ceil(521/8)
        default:
            throw SecureMimeError.invalidPrivateKey("Unsupported EC key size: \(keySize)")
        }

        // X9.63 private key: 1 (prefix) + scalarSize (X) + scalarSize (Y) + scalarSize (K)
        let expectedX963Size = 1 + 3 * scalarSize

        // Try DER/PKCS#8 format first (most common from Security framework export)
        // DER-encoded keys are typically larger due to ASN.1 overhead
        if keyData.count > expectedX963Size {
            switch keySize {
            case 256:
                if let key = try? P256.Signing.PrivateKey(derRepresentation: keyData) {
                    return Certificate.PrivateKey(key)
                }
            case 384:
                if let key = try? P384.Signing.PrivateKey(derRepresentation: keyData) {
                    return Certificate.PrivateKey(key)
                }
            case 521:
                if let key = try? P521.Signing.PrivateKey(derRepresentation: keyData) {
                    return Certificate.PrivateKey(key)
                }
            default:
                break
            }
        }

        // Try x963Representation (raw format from SecKeyCopyExternalRepresentation)
        if keyData.count == expectedX963Size {
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
        }

        // Try rawRepresentation (just the scalar)
        if keyData.count == scalarSize {
            switch keySize {
            case 256:
                let key = try P256.Signing.PrivateKey(rawRepresentation: keyData)
                return Certificate.PrivateKey(key)
            case 384:
                let key = try P384.Signing.PrivateKey(rawRepresentation: keyData)
                return Certificate.PrivateKey(key)
            case 521:
                let key = try P521.Signing.PrivateKey(rawRepresentation: keyData)
                return Certificate.PrivateKey(key)
            default:
                break
            }
        }

        // Try extracting the scalar from the end of X9.63 format
        if keyData.count == expectedX963Size {
            let scalarStart = keyData.count - scalarSize
            let scalarData = keyData.suffix(from: scalarStart)
            switch keySize {
            case 256:
                if let key = try? P256.Signing.PrivateKey(rawRepresentation: scalarData) {
                    return Certificate.PrivateKey(key)
                }
            case 384:
                if let key = try? P384.Signing.PrivateKey(rawRepresentation: scalarData) {
                    return Certificate.PrivateKey(key)
                }
            case 521:
                if let key = try? P521.Signing.PrivateKey(rawRepresentation: scalarData) {
                    return Certificate.PrivateKey(key)
                }
            default:
                break
            }
        }

        throw SecureMimeError.invalidPrivateKey(
            "EC key data format not recognized. Size: \(keyData.count), expected X9.63 size: \(expectedX963Size)"
        )
    }

    /// Converts a SecKey to a Certificate.PrivateKey.
    private static func convertSecKeyToPrivateKey(_ secKey: SecKey) throws -> Certificate.PrivateKey {
        // Get the key type and size
        guard let attributes = SecKeyCopyAttributes(secKey) as? [String: Any] else {
            throw SecureMimeError.invalidPrivateKey("Failed to get key attributes")
        }

        let keyType = attributes[kSecAttrKeyType as String] as? String
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 0

        // Export the key data
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(secKey, &error) as Data? else {
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw SecureMimeError.invalidPrivateKey("Failed to export private key: \(errorDesc)")
        }

        return try convertKeyData(keyData, keyType: keyType, keySize: keySize)
    }
    #endif

    /// The signature algorithm to use based on the private key type and digest algorithm.
    ///
    /// This property automatically selects the appropriate signature algorithm
    /// based on the type of private key and the configured ``digestAlgorithm``.
    /// For example, an EC key with SHA-256 digest will use ECDSA with SHA-256,
    /// while an RSA key will use RSA-SHA256.
    internal var signatureAlgorithm: Certificate.SignatureAlgorithm {
        let supported = privateKey.supportedSignatureAlgorithms

        switch digestAlgorithm {
        case .sha256:
            if supported.contains(.ecdsaWithSHA256) {
                return .ecdsaWithSHA256
            } else if supported.contains(.sha256WithRSAEncryption) {
                return .sha256WithRSAEncryption
            }
        case .sha384:
            if supported.contains(.ecdsaWithSHA384) {
                return .ecdsaWithSHA384
            } else if supported.contains(.sha384WithRSAEncryption) {
                return .sha384WithRSAEncryption
            }
        case .sha512:
            if supported.contains(.ecdsaWithSHA512) {
                return .ecdsaWithSHA512
            } else if supported.contains(.sha512WithRSAEncryption) {
                return .sha512WithRSAEncryption
            }
        case .sha1:
            if supported.contains(.sha1WithRSAEncryption) {
                return .sha1WithRSAEncryption
            }
        case .md5, .none:
            break
        }

        // Fall back to a sensible default based on what's supported
        if supported.contains(.ecdsaWithSHA256) {
            return .ecdsaWithSHA256
        } else if supported.contains(.sha256WithRSAEncryption) {
            return .sha256WithRSAEncryption
        } else if supported.contains(.ed25519) {
            return .ed25519
        } else if let first = supported.first {
            return first
        }

        // Ultimate fallback (shouldn't reach here with valid keys)
        return .sha256WithRSAEncryption
    }
}
