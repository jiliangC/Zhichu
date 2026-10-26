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
// DkimVerifier.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A DKIM-Signature verifier.
///
/// Verifies DomainKeys Identified Mail (DKIM) signatures as specified in RFC 6376.
///
/// DKIM provides a method for validating a domain name identity that is associated
/// with a message through cryptographic authentication. The verifier uses a
/// ``DkimPublicKeyLocator`` to retrieve the signer's public key via DNS.
///
/// ## Usage
///
/// ```swift
/// // Create a verifier with a public key locator
/// let locator = MyDkimPublicKeyLocator()
/// let verifier = DkimVerifier(publicKeyLocator: locator)
///
/// // Find and verify DKIM signatures
/// for header in message.headers {
///     if header.id == .dkimSignature {
///         let isValid = try verifier.verify(message, header)
///         print("Signature valid: \(isValid)")
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Verifier
/// - ``init(publicKeyLocator:)``
///
/// ### Verifying Signatures
/// - ``verify(_:_:_:)``
/// - ``verify(_:_:)``
/// - ``verifyAsync(_:_:_:)``
/// - ``verifyAsync(_:_:)``
///
/// ### Related Types
/// - ``DkimPublicKeyLocator``
/// - ``DkimSignatureAlgorithm``
public final class DkimVerifier: DkimVerifierBase {
    /// Creates a new DKIM verifier with the specified public key locator.
    ///
    /// - Parameter publicKeyLocator: The service used to retrieve public keys for
    ///   signature verification. This is typically implemented using DNS lookups.
    public override init(publicKeyLocator: DkimPublicKeyLocator) {
        super.init(publicKeyLocator: publicKeyLocator)
    }

    /// Verifies the specified DKIM-Signature header.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use when canonicalizing the message.
    ///   - message: The message containing the signature to verify.
    ///   - dkimSignature: The DKIM-Signature header to verify.
    /// - Returns: `true` if the DKIM-Signature is valid; otherwise, `false`.
    /// - Throws: ``DkimVerifierError/invalidArgument`` if `dkimSignature` is not
    ///   a DKIM-Signature header, or ``DkimVerifierError/malformedHeader(_:)`` if
    ///   the header value is malformed.
    public func verify(_ options: FormatOptions, _ message: MimeMessage, _ dkimSignature: Header) throws -> Bool {
        try verifyInternal(options: options, message: message, dkimSignature: dkimSignature)
    }

    /// Verifies the specified DKIM-Signature header using default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message containing the signature to verify.
    ///   - dkimSignature: The DKIM-Signature header to verify.
    /// - Returns: `true` if the DKIM-Signature is valid; otherwise, `false`.
    /// - Throws: ``DkimVerifierError/invalidArgument`` if `dkimSignature` is not
    ///   a DKIM-Signature header, or ``DkimVerifierError/malformedHeader(_:)`` if
    ///   the header value is malformed.
    public func verify(_ message: MimeMessage, _ dkimSignature: Header) throws -> Bool {
        try verify(.default, message, dkimSignature)
    }

    /// Asynchronously verifies the specified DKIM-Signature header.
    ///
    /// This method supports cancellation through Swift's structured concurrency.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use when canonicalizing the message.
    ///   - message: The message containing the signature to verify.
    ///   - dkimSignature: The DKIM-Signature header to verify.
    /// - Returns: `true` if the DKIM-Signature is valid; otherwise, `false`.
    /// - Throws: ``DkimVerifierError/invalidArgument`` if `dkimSignature` is not
    ///   a DKIM-Signature header, ``DkimVerifierError/malformedHeader(_:)`` if
    ///   the header value is malformed, or `CancellationError` if the task is cancelled.
    public func verifyAsync(_ options: FormatOptions, _ message: MimeMessage, _ dkimSignature: Header) async throws -> Bool {
        try Task.checkCancellation()
        return try await verifyInternalAsync(options: options, message: message, dkimSignature: dkimSignature)
    }

    /// Asynchronously verifies the specified DKIM-Signature header using default formatting options.
    ///
    /// This method supports cancellation through Swift's structured concurrency.
    ///
    /// - Parameters:
    ///   - message: The message containing the signature to verify.
    ///   - dkimSignature: The DKIM-Signature header to verify.
    /// - Returns: `true` if the DKIM-Signature is valid; otherwise, `false`.
    /// - Throws: ``DkimVerifierError/invalidArgument`` if `dkimSignature` is not
    ///   a DKIM-Signature header, ``DkimVerifierError/malformedHeader(_:)`` if
    ///   the header value is malformed, or `CancellationError` if the task is cancelled.
    public func verifyAsync(_ message: MimeMessage, _ dkimSignature: Header) async throws -> Bool {
        try await verifyAsync(.default, message, dkimSignature)
    }

    private func verifyInternal(options: FormatOptions, message: MimeMessage, dkimSignature: Header) throws -> Bool {
        var options = options.copy()
        options.newLineFormat = .dos

        guard dkimSignature.id == .dkimSignature else {
            throw DkimVerifierError.invalidArgument
        }

        let parameters = try DkimVerifierBase.parseParameterTags(headerId: dkimSignature.id, signature: dkimSignature.value)
        let validated = try validateDkimSignatureParameters(parameters)

        if !isEnabled(validated.algorithm) {
            return false
        }

        let bodyOk = try DkimVerifierBase.verifyBodyHash(options: options, message: message, signatureAlgorithm: validated.algorithm, canonicalizationAlgorithm: validated.bodyAlgorithm, maxLength: validated.maxLength, bodyHash: validated.bh)
        if !bodyOk {
            return false
        }

        let key = try locatePublicKey(methods: validated.q, domain: validated.d, selector: validated.s)

        if case .rsa(let rsa) = key {
            if rsa.keySizeInBits < minimumRsaKeyLength {
                return false
            }
        }

        return try verifySignature(options: options, message: message, dkimSignature: dkimSignature, signatureAlgorithm: validated.algorithm, key: key, headers: validated.headers, canonicalizationAlgorithm: validated.headerAlgorithm, signature: validated.b)
    }

    private func verifyInternalAsync(options: FormatOptions, message: MimeMessage, dkimSignature: Header) async throws -> Bool {
        var options = options.copy()
        options.newLineFormat = .dos

        guard dkimSignature.id == .dkimSignature else {
            throw DkimVerifierError.invalidArgument
        }

        let parameters = try DkimVerifierBase.parseParameterTags(headerId: dkimSignature.id, signature: dkimSignature.value)
        let validated = try validateDkimSignatureParameters(parameters)

        if !isEnabled(validated.algorithm) {
            return false
        }

        let bodyOk = try DkimVerifierBase.verifyBodyHash(options: options, message: message, signatureAlgorithm: validated.algorithm, canonicalizationAlgorithm: validated.bodyAlgorithm, maxLength: validated.maxLength, bodyHash: validated.bh)
        if !bodyOk {
            return false
        }

        let key = try await locatePublicKeyAsync(methods: validated.q, domain: validated.d, selector: validated.s)
        if case .rsa(let rsa) = key {
            if rsa.keySizeInBits < minimumRsaKeyLength {
                return false
            }
        }

        return try verifySignature(options: options, message: message, dkimSignature: dkimSignature, signatureAlgorithm: validated.algorithm, key: key, headers: validated.headers, canonicalizationAlgorithm: validated.headerAlgorithm, signature: validated.b)
    }

    private func validateDkimSignatureParameters(_ parameters: [String: String]) throws -> (algorithm: DkimSignatureAlgorithm, headerAlgorithm: DkimCanonicalizationAlgorithm, bodyAlgorithm: DkimCanonicalizationAlgorithm, d: String, s: String, q: String, headers: [String], bh: String, b: String, maxLength: Int) {
        guard let v = parameters["v"] else {
            throw DkimVerifierError.malformedHeader("Malformed DKIM-Signature header: no version parameter detected.")
        }
        guard v == "1" else {
            throw DkimVerifierError.malformedHeader("Unrecognized DKIM-Signature version: v=\(v)")
        }

        let common = try DkimVerifierBase.validateCommonSignatureParameters(header: "DKIM-Signature", parameters: parameters)

        let containsFrom = common.headers.contains { $0.caseInsensitiveCompare("from") == .orderedSame }
        if !containsFrom {
            throw DkimVerifierError.malformedHeader("Malformed DKIM-Signature header: From header not signed.")
        }

        if let id = parameters["i"] {
            if let atIndex = id.lastIndex(of: "@") {
                let domain = String(id[id.index(after: atIndex)...])
                let domainLower = domain.lowercased()
                let dLower = common.d.lowercased()
                if domainLower != dLower && !domainLower.hasSuffix("." + dLower) {
                    throw DkimVerifierError.malformedHeader("Invalid DKIM-Signature header: the domain in the AUID does not match the domain parameter.")
                }
            } else {
                throw DkimVerifierError.malformedHeader("Malformed DKIM-Signature header: no @ in the AUID value.")
            }
        }

        return common
    }
}
