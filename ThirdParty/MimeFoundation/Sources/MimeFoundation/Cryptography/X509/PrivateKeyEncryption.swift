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
// PrivateKeyEncryption.swift
//
// Password-based encryption for private key storage.
//

import Foundation
@_spi(CMS) import X509
import Crypto
import SwiftASN1

/// Errors that can occur during private key encryption/decryption.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public enum PrivateKeyEncryptionError: Error, Sendable {
    /// The password is incorrect or the data is corrupted.
    case decryptionFailed(String)

    /// The encrypted data format is invalid.
    case invalidFormat(String)

    /// The private key format is not supported.
    case unsupportedKeyFormat(String)

    /// Encryption failed.
    case encryptionFailed(String)
}

/// Provides password-based encryption for private keys using PBKDF2 and AES-256-GCM.
///
/// This struct provides methods to securely encrypt and decrypt private keys
/// for storage. It uses:
/// - PBKDF2-HMAC-SHA256 for key derivation (100,000 iterations)
/// - AES-256-GCM for authenticated encryption
///
/// ## Usage
///
/// ```swift
/// let key = P256.Signing.PrivateKey()
/// let privateKey = Certificate.PrivateKey(key)
///
/// // Encrypt for storage
/// let encrypted = try PrivateKeyEncryption.encrypt(privateKey: privateKey, password: "secret")
///
/// // Decrypt when needed
/// let decrypted = try PrivateKeyEncryption.decrypt(encryptedKey: encrypted, password: "secret")
/// ```
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public enum PrivateKeyEncryption {
    /// The number of PBKDF2 iterations to use for key derivation.
    ///
    /// Higher values increase security but also increase computation time.
    /// The default of 100,000 provides a good balance for most use cases.
    public static let defaultIterations: Int = 100_000

    /// The size of the salt in bytes.
    private static let saltSize: Int = 32

    /// The size of the nonce for AES-GCM.
    private static let nonceSize: Int = 12

    /// Magic bytes to identify the encrypted format.
    private static let magicBytes: [UInt8] = [0x50, 0x4B, 0x45, 0x31] // "PKE1"

    /// Encrypts a private key using password-based encryption.
    ///
    /// The encryption uses:
    /// - A randomly generated 32-byte salt
    /// - PBKDF2-HMAC-SHA256 with the specified iterations for key derivation
    /// - AES-256-GCM for authenticated encryption
    ///
    /// The output format is:
    /// `magic (4) || iterations (4) || salt (32) || nonce (12) || ciphertext || tag (16)`
    ///
    /// - Parameters:
    ///   - privateKey: The private key to encrypt.
    ///   - password: The password to use for encryption.
    ///   - iterations: The number of PBKDF2 iterations (default: 100,000).
    /// - Returns: The encrypted key bytes.
    /// - Throws: `PrivateKeyEncryptionError` if encryption fails.
    public static func encrypt(
        privateKey: Certificate.PrivateKey,
        password: String,
        iterations: Int = defaultIterations
    ) throws -> [UInt8] {
        // Serialize the private key to PKCS#8 PEM format and extract DER bytes
        let pemDoc: PEMDocument
        do {
            pemDoc = try privateKey.serializeAsPEM()
        } catch {
            throw PrivateKeyEncryptionError.encryptionFailed("Failed to serialize private key: \(error)")
        }
        let keyBytes = pemDoc.derBytes

        // Generate random salt
        var salt = [UInt8](repeating: 0, count: saltSize)
        guard SecRandomCopyBytes(kSecRandomDefault, saltSize, &salt) == errSecSuccess else {
            throw PrivateKeyEncryptionError.encryptionFailed("Failed to generate random salt")
        }

        // Derive encryption key using PBKDF2
        let derivedKey = try deriveKey(password: password, salt: salt, iterations: iterations)

        // Generate random nonce
        let nonce = try AES.GCM.Nonce()

        // Encrypt with AES-256-GCM
        let symmetricKey = SymmetricKey(data: derivedKey)
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.seal(keyBytes, using: symmetricKey, nonce: nonce)
        } catch {
            throw PrivateKeyEncryptionError.encryptionFailed("AES-GCM encryption failed: \(error)")
        }

        // Build output: magic || iterations || salt || nonce || ciphertext || tag
        var output: [UInt8] = []
        output.append(contentsOf: magicBytes)

        // Append iterations as 4 bytes (big-endian)
        output.append(UInt8((iterations >> 24) & 0xFF))
        output.append(UInt8((iterations >> 16) & 0xFF))
        output.append(UInt8((iterations >> 8) & 0xFF))
        output.append(UInt8(iterations & 0xFF))

        output.append(contentsOf: salt)
        output.append(contentsOf: nonce.withUnsafeBytes { Array($0) })
        output.append(contentsOf: sealedBox.ciphertext)
        output.append(contentsOf: sealedBox.tag)

        return output
    }

    /// Decrypts a private key that was encrypted with `encrypt(privateKey:password:)`.
    ///
    /// - Parameters:
    ///   - encryptedKey: The encrypted key bytes.
    ///   - password: The password used for encryption.
    /// - Returns: The decrypted private key.
    /// - Throws: `PrivateKeyEncryptionError` if decryption fails.
    public static func decrypt(
        encryptedKey: [UInt8],
        password: String
    ) throws -> Certificate.PrivateKey {
        // Minimum size: magic (4) + iterations (4) + salt (32) + nonce (12) + tag (16) = 68
        guard encryptedKey.count > 68 else {
            throw PrivateKeyEncryptionError.invalidFormat("Encrypted data too short")
        }

        // Verify magic bytes
        guard Array(encryptedKey.prefix(4)) == magicBytes else {
            throw PrivateKeyEncryptionError.invalidFormat("Invalid magic bytes")
        }

        var offset = 4

        // Read iterations
        let iterations = (Int(encryptedKey[offset]) << 24) |
                        (Int(encryptedKey[offset + 1]) << 16) |
                        (Int(encryptedKey[offset + 2]) << 8) |
                        Int(encryptedKey[offset + 3])
        offset += 4

        // Read salt
        let salt = Array(encryptedKey[offset..<(offset + saltSize)])
        offset += saltSize

        // Read nonce
        let nonceBytes = Array(encryptedKey[offset..<(offset + nonceSize)])
        offset += nonceSize

        // Read ciphertext and tag
        let ciphertextAndTag = Array(encryptedKey[offset...])
        guard ciphertextAndTag.count >= 16 else {
            throw PrivateKeyEncryptionError.invalidFormat("Missing authentication tag")
        }

        // Derive decryption key
        let derivedKey = try deriveKey(password: password, salt: salt, iterations: iterations)
        let symmetricKey = SymmetricKey(data: derivedKey)

        // Create nonce and sealed box
        let nonce: AES.GCM.Nonce
        do {
            nonce = try AES.GCM.Nonce(data: nonceBytes)
        } catch {
            throw PrivateKeyEncryptionError.invalidFormat("Invalid nonce: \(error)")
        }

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertextAndTag.dropLast(16), tag: ciphertextAndTag.suffix(16))
        } catch {
            throw PrivateKeyEncryptionError.invalidFormat("Invalid sealed box: \(error)")
        }

        // Decrypt
        let decryptedBytes: Data
        do {
            decryptedBytes = try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw PrivateKeyEncryptionError.decryptionFailed("Decryption failed - wrong password or corrupted data")
        }

        // Parse the private key
        do {
            return try Certificate.PrivateKey(derBytes: Array(decryptedBytes))
        } catch {
            throw PrivateKeyEncryptionError.unsupportedKeyFormat("Failed to parse private key: \(error)")
        }
    }

    /// Derives an encryption key from a password using PBKDF2-HMAC-SHA256.
    ///
    /// - Parameters:
    ///   - password: The password to derive from.
    ///   - salt: The salt bytes.
    ///   - iterations: The number of PBKDF2 iterations.
    /// - Returns: A 32-byte derived key.
    private static func deriveKey(
        password: String,
        salt: [UInt8],
        iterations: Int
    ) throws -> [UInt8] {
        guard let passwordData = password.data(using: .utf8) else {
            throw PrivateKeyEncryptionError.encryptionFailed("Invalid password encoding")
        }

        var derivedKey = [UInt8](repeating: 0, count: 32)

        let result = derivedKey.withUnsafeMutableBytes { derivedKeyPtr in
            salt.withUnsafeBytes { saltPtr in
                passwordData.withUnsafeBytes { passwordPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw PrivateKeyEncryptionError.encryptionFailed("PBKDF2 key derivation failed with status: \(result)")
        }

        return derivedKey
    }
}

// CommonCrypto PBKDF2 definitions
private let kCCPBKDF2: Int = 2
private let kCCPRFHmacAlgSHA256: Int = 2
private let kCCSuccess: Int32 = 0

private typealias CCPBKDFAlgorithm = UInt32
private typealias CCPseudoRandomAlgorithm = UInt32

@_silgen_name("CCKeyDerivationPBKDF")
private func CCKeyDerivationPBKDF(
    _ algorithm: CCPBKDFAlgorithm,
    _ password: UnsafePointer<Int8>?,
    _ passwordLen: Int,
    _ salt: UnsafePointer<UInt8>?,
    _ saltLen: Int,
    _ prf: CCPseudoRandomAlgorithm,
    _ rounds: UInt32,
    _ derivedKey: UnsafeMutablePointer<UInt8>?,
    _ derivedKeyLen: Int
) -> Int32
