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
// AppleSecureMimeContext.swift
//
// S/MIME context implementation using Apple Security framework for encryption.
//
// This context is only available on macOS and uses CMSEncoder/CMSDecoder
// for CMS encryption operations.
//

import Foundation
@_spi(CMS) import X509

#if os(macOS)
import Security

/// S/MIME context implementation using Apple's Security framework.
///
/// This context provides full S/MIME support including encryption and decryption
/// by using the macOS CMSEncoder and CMSDecoder APIs. It uses swift-certificates
/// for signing operations and Security framework for encryption.
///
/// - Note: This context is only available on macOS. On other Apple platforms,
///   use `DefaultSecureMimeContext` (signing only) or wait for swift-certificates
///   to add EnvelopedData support.
@available(macOS 11.0, *)
public final class AppleSecureMimeContext: SecureMimeContext, @unchecked Sendable {

    /// Shared instance of the Apple S/MIME context.
    public static let shared = AppleSecureMimeContext()

    /// Creates a new Apple S/MIME context.
    public override init() {
        super.init()
    }

    /// Returns whether this context supports encryption.
    public override var supportsEncryption: Bool { true }

    /// Returns whether this context supports decryption.
    public override var supportsDecryption: Bool { true }

    // MARK: - Encryption

    /// Encrypts the provided content bytes for the specified recipients.
    ///
    /// - Parameters:
    ///   - recipients: The recipients who will be able to decrypt the message.
    ///   - content: The content bytes to encrypt.
    /// - Returns: The encrypted CMS content bytes.
    /// - Throws: `SecureMimeError` if encryption fails.
    public override func encrypt(
        recipients: CmsRecipientCollection,
        content: [UInt8]
    ) throws -> [UInt8] {
        guard !recipients.isEmpty else {
            throw SecureMimeError.invalidArgument("At least one recipient is required for encryption")
        }

        // Convert recipients to SecCertificateRefs
        var secCertificates: [SecCertificate] = []
        for recipient in recipients {
            let secCert = try recipient.toSecCertificate()
            secCertificates.append(secCert)
        }

        // Create the recipients array
        let recipientsArray: CFArray = secCertificates as CFArray

        // Use CMSEncodeContent for encryption
        var encodedData: CFData?
        let status = CMSEncodeContent(
            nil,                    // signers (none for encryption only)
            recipientsArray,        // recipients
            nil,                    // eContentTypeOID (default)
            false,                  // detachedContent
            CMSSignedAttributes(rawValue: 0), // signedAttributes
            content,                // content
            content.count,          // contentLen
            &encodedData            // output
        )

        guard status == errSecSuccess, let data = encodedData else {
            throw SecureMimeError.signingFailed("CMSEncodeContent failed with status: \(status)")
        }

        return Array(data as Data)
    }

    /// Signs and encrypts content in a single CMS operation.
    ///
    /// This method uses the Security framework's nested ContentInfo support
    /// to create an EnvelopedData containing a SignedData.
    ///
    /// - Parameters:
    ///   - signer: The CMS signer for signing.
    ///   - recipients: The recipients who will be able to decrypt the message.
    ///   - entity: The MIME entity to sign and encrypt.
    /// - Returns: An `ApplicationPkcs7Mime` containing the signed and encrypted content.
    /// - Throws: `SecureMimeError` if signing or encryption fails.
    public override func signAndEncrypt(
        signer: CmsSigner,
        recipients: CmsRecipientCollection,
        entity: MimeEntity
    ) throws -> ApplicationPkcs7Mime {
        guard !recipients.isEmpty else {
            throw SecureMimeError.invalidArgument("At least one recipient is required for encryption")
        }

        let contentBytes = try serializeEntity(entity)

        // Convert signer to SecIdentity
        let secIdentity = try createSecIdentity(from: signer)

        // Convert recipients to SecCertificateRefs
        var secCertificates: [SecCertificate] = []
        for recipient in recipients {
            let secCert = try recipient.toSecCertificate()
            secCertificates.append(secCert)
        }

        // Use CMSEncodeContent for combined sign+encrypt
        var encodedData: CFData?
        let status = CMSEncodeContent(
            secIdentity,                    // signers
            secCertificates as CFArray,     // recipients
            nil,                            // eContentTypeOID
            false,                          // detachedContent
            CMSSignedAttributes.attrSigningTime, // signedAttributes
            contentBytes,                   // content
            contentBytes.count,             // contentLen
            &encodedData                    // output
        )

        guard status == errSecSuccess, let data = encodedData else {
            throw SecureMimeError.signingFailed("CMSEncodeContent (sign+encrypt) failed with status: \(status)")
        }

        return ApplicationPkcs7Mime(Array(data as Data), smimeType: .envelopedData)
    }

    // MARK: - Decryption

    /// Decrypts the provided CMS encrypted content.
    ///
    /// - Parameter encryptedBytes: The encrypted CMS content bytes.
    /// - Returns: The decrypted content bytes.
    /// - Throws: `SecureMimeError` if decryption fails.
    ///
    /// - Note: Decryption requires that the recipient's private key is available
    ///   in the user's keychain.
    public override func decrypt(encryptedBytes: [UInt8]) throws -> [UInt8] {
        // Create decoder
        var decoder: CMSDecoder?
        var status = CMSDecoderCreate(&decoder)
        guard status == errSecSuccess, let cmsDecoder = decoder else {
            throw SecureMimeError.invalidSignatureData("Failed to create CMS decoder: \(status)")
        }
        // Note: cmsDecoder is automatically released by ARC when it goes out of scope

        // Feed the encrypted data
        status = CMSDecoderUpdateMessage(cmsDecoder, encryptedBytes, encryptedBytes.count)
        guard status == errSecSuccess else {
            throw SecureMimeError.invalidSignatureData("Failed to update CMS decoder: \(status)")
        }

        // Finalize decoding
        status = CMSDecoderFinalizeMessage(cmsDecoder)
        guard status == errSecSuccess else {
            throw SecureMimeError.invalidSignatureData("Failed to finalize CMS decoder: \(status)")
        }

        // Get decrypted content
        var content: CFData?
        status = CMSDecoderCopyContent(cmsDecoder, &content)
        guard status == errSecSuccess, let decryptedData = content else {
            throw SecureMimeError.invalidSignatureData("Failed to get decrypted content: \(status)")
        }

        return Array(decryptedData as Data)
    }

    // MARK: - Helpers

    /// Creates a SecIdentity from a CmsSigner.
    ///
    /// This requires adding the certificate and private key to a temporary keychain
    /// or finding a matching identity in the default keychain.
    private func createSecIdentity(from signer: CmsSigner) throws -> SecIdentity {
        // First, convert the certificate to SecCertificate
        let secCert = try SecCertificate.makeWithCertificate(signer.certificate)

        // Try to find a matching identity in the keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let identities = result as? [SecIdentity] {
            // Find an identity with a matching certificate
            for identity in identities {
                var certRef: SecCertificate?
                if SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
                   let cert = certRef {
                    // Compare certificates by their data
                    let certData1 = SecCertificateCopyData(cert) as Data
                    let certData2 = SecCertificateCopyData(secCert) as Data
                    if certData1 == certData2 {
                        return identity
                    }
                }
            }
        }

        // If no matching identity found, we need to create one
        // This would require importing the private key to the keychain
        throw SecureMimeError.invalidPrivateKey(
            "No matching identity found in keychain. The certificate and private key must be imported to the keychain for signing with Security framework."
        )
    }
}

#else

// Stub for non-macOS platforms
@available(iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public final class AppleSecureMimeContext: SecureMimeContext {
    public static let shared = AppleSecureMimeContext()

    public override init() {
        super.init()
    }

    public override var supportsEncryption: Bool { false }
    public override var supportsDecryption: Bool { false }
}

#endif
