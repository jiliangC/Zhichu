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
// SecureMimeError.swift
//
// Error types for S/MIME operations.
//

import Foundation

/// Errors that can occur during S/MIME cryptographic operations.
///
/// These errors represent various failure conditions when signing, verifying,
/// encrypting, or decrypting S/MIME messages.
///
/// ## Topics
///
/// ### Certificate Errors
/// - ``invalidCertificate(_:)``
/// - ``noSignerCertificate``
///
/// ### Key Errors
/// - ``invalidPrivateKey(_:)``
/// - ``pkcs12LoadFailed(_:)``
///
/// ### Algorithm Errors
/// - ``unsupportedAlgorithm(_:)``
///
/// ### Signature Errors
/// - ``signatureVerificationFailed(_:)``
/// - ``invalidSignatureData(_:)``
/// - ``contentMismatch(_:)``
/// - ``signingFailed(_:)``
///
/// ### Format Errors
/// - ``invalidMultipartSigned(_:)``
/// - ``fileReadFailed(_:)``
/// - ``invalidArgument(_:)``
public enum SecureMimeError: Error, Equatable, Sendable {
    /// The certificate is invalid or could not be parsed.
    ///
    /// This error occurs when a certificate cannot be loaded from PEM, DER,
    /// or PKCS#12 format, or when the certificate format is not recognized.
    case invalidCertificate(String)

    /// The private key is invalid or could not be parsed.
    ///
    /// This error occurs when a private key cannot be loaded from PEM, DER,
    /// or PKCS#12 format, or when the key format is not recognized.
    case invalidPrivateKey(String)

    /// The specified algorithm is not supported.
    ///
    /// This error occurs when attempting to use an encryption or signature
    /// algorithm that is not available in the current context.
    case unsupportedAlgorithm(String)

    /// Signature verification failed.
    ///
    /// This error occurs when the cryptographic signature does not match
    /// the signed content, or when the signature cannot be verified for
    /// other cryptographic reasons.
    case signatureVerificationFailed(String)

    /// Failed to load PKCS#12 data.
    ///
    /// This error occurs when PKCS#12 (.p12/.pfx) data cannot be parsed,
    /// typically due to an incorrect password or corrupted data.
    case pkcs12LoadFailed(String)

    /// The signature data is malformed or invalid.
    ///
    /// This error occurs when the CMS signature structure cannot be parsed
    /// or is missing required fields.
    case invalidSignatureData(String)

    /// The signed content does not match the signature.
    ///
    /// This error indicates that the content has been modified since it
    /// was signed, or the wrong content was provided for verification.
    case contentMismatch(String)

    /// No signer certificate was found in the signature.
    ///
    /// This error occurs when the CMS signature does not include the
    /// signer's certificate and it cannot be located otherwise.
    case noSignerCertificate

    /// Failed to create the signature.
    ///
    /// This error occurs during the signing process, typically due to
    /// issues with the private key or certificate.
    case signingFailed(String)

    /// The multipart/signed structure is invalid.
    ///
    /// This error occurs when a `multipart/signed` message does not have
    /// the expected structure (content part and signature part).
    case invalidMultipartSigned(String)

    /// File read operation failed.
    ///
    /// This error occurs when a certificate or key file cannot be read,
    /// typically due to permission issues or the file not existing.
    case fileReadFailed(String)

    /// An argument was invalid.
    ///
    /// This error occurs when an invalid argument is passed to an S/MIME
    /// operation.
    case invalidArgument(String)
}

extension SecureMimeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCertificate(let message):
            return "Invalid certificate: \(message)"
        case .invalidPrivateKey(let message):
            return "Invalid private key: \(message)"
        case .unsupportedAlgorithm(let algorithm):
            return "Unsupported algorithm: \(algorithm)"
        case .signatureVerificationFailed(let message):
            return "Signature verification failed: \(message)"
        case .pkcs12LoadFailed(let message):
            return "Failed to load PKCS#12: \(message)"
        case .invalidSignatureData(let message):
            return "Invalid signature data: \(message)"
        case .contentMismatch(let message):
            return "Content mismatch: \(message)"
        case .noSignerCertificate:
            return "No signer certificate found in signature"
        case .signingFailed(let message):
            return "Signing failed: \(message)"
        case .invalidMultipartSigned(let message):
            return "Invalid multipart/signed: \(message)"
        case .fileReadFailed(let message):
            return "File read failed: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        }
    }
}
