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
// MultipartSigned.swift
//
// Multipart container for S/MIME signed messages.
//

import Foundation
@_spi(CMS) import X509

/// Represents a `multipart/signed` MIME entity.
///
/// A multipart/signed entity contains two parts:
/// 1. The original content that was signed
/// 2. A detached signature (typically `application/pkcs7-signature`)
///
/// This class provides factory methods for creating signed messages
/// and accessing the signed content and signature parts.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public class MultipartSigned: Multipart {

    /// Creates a new empty multipart/signed entity.
    public convenience init() {
        do {
            try self.init("signed")
        } catch {
            preconditionFailure("Failed to create multipart/signed - this is a programming error")
        }
    }

    /// Creates a signed multipart message from the given entity and signer.
    ///
    /// - Parameters:
    ///   - entity: The MIME entity to sign.
    ///   - signer: The CMS signer to use.
    ///   - context: The S/MIME context to use. Defaults to `DefaultSecureMimeContext.shared`.
    /// - Returns: A new `MultipartSigned` containing the entity and its signature.
    /// - Throws: `SecureMimeError` if signing fails.
    public static func create(
        _ entity: MimeEntity,
        signer: CmsSigner,
        context: SecureMimeContext = DefaultSecureMimeContext.shared
    ) throws -> MultipartSigned {
        let signed = MultipartSigned()

        // Set the protocol parameter
        signed.contentType.parameters["protocol"] = SecureMimeContext.signatureProtocol

        // Set the micalg parameter
        signed.contentType.parameters["micalg"] = signer.digestAlgorithm.micalg

        // Add the content part
        try signed.add(entity)

        // Create and add the signature part
        let signature = try context.createSignature(signer, entity: entity)
        try signed.add(signature)

        return signed
    }

    /// Asynchronously creates a signed multipart message from the given entity and signer.
    ///
    /// - Parameters:
    ///   - entity: The MIME entity to sign.
    ///   - signer: The CMS signer to use.
    ///   - context: The S/MIME context to use. Defaults to `DefaultSecureMimeContext.shared`.
    /// - Returns: A new `MultipartSigned` containing the entity and its signature.
    /// - Throws: `SecureMimeError` if signing fails.
    public static func createAsync(
        _ entity: MimeEntity,
        signer: CmsSigner,
        context: SecureMimeContext = DefaultSecureMimeContext.shared
    ) async throws -> MultipartSigned {
        try create(entity, signer: signer, context: context)
    }

    /// The content entity that was signed.
    ///
    /// This is the first part of the multipart/signed structure.
    public var signedContent: MimeEntity? {
        guard count >= 1 else { return nil }
        return self[0]
    }

    /// The signature part.
    ///
    /// This is the second part of the multipart/signed structure.
    public var signature: ApplicationPkcs7Signature? {
        guard count >= 2 else { return nil }
        return self[1] as? ApplicationPkcs7Signature
    }

    /// The micalg (Message Integrity Check Algorithm) parameter value.
    ///
    /// This indicates the digest algorithm used for the signature.
    public var micalg: String? {
        get { contentType.parameters["micalg"] }
        set { contentType.parameters["micalg"] = newValue }
    }

    /// The protocol parameter value.
    ///
    /// This indicates the signature protocol (typically "application/pkcs7-signature").
    public var signatureProtocol: String? {
        get { contentType.parameters["protocol"] }
        set { contentType.parameters["protocol"] = newValue }
    }

    /// Verifies the signature using the specified context and trust roots.
    ///
    /// - Parameters:
    ///   - context: The S/MIME context to use for verification.
    ///   - trustRoots: The certificate store containing trusted root certificates.
    /// - Returns: A tuple containing the verification results and the signed content.
    /// - Throws: `SecureMimeError` if verification fails.
    public func verify(
        context: SecureMimeContext = DefaultSecureMimeContext.shared,
        trustRoots: CertificateStore
    ) async throws -> (signatures: DigitalSignatureCollection, content: MimeEntity) {
        try await context.verify(multipartSigned: self, trustRoots: trustRoots)
    }

    /// Accepts a MIME visitor.
    ///
    /// - Parameter visitor: The visitor to accept.
    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }
}
