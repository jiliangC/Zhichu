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
// ChainValidationResult.swift
//
// Result type for certificate chain validation.
//

import Foundation
@_spi(CMS) import X509

/// The result of X.509 certificate chain validation.
///
/// This struct contains the validation outcome, including whether the chain
/// is valid, the validated chain (if successful), and any error that occurred.
///
/// ## Usage
///
/// ```swift
/// let result = await validator.validate(
///     leaf: certificate,
///     intermediates: intermediates,
///     trustRoots: trustStore
/// )
///
/// if result.isValid {
///     print("Chain validated successfully")
///     print("Chain length: \(result.chain?.count ?? 0)")
/// } else {
///     print("Validation failed: \(result.error?.localizedDescription ?? "Unknown")")
/// }
/// ```
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct ChainValidationResult: Sendable {
    /// Whether the certificate chain is valid.
    public let isValid: Bool

    /// The validated certificate chain from leaf to root, if validation succeeded.
    ///
    /// The chain includes:
    /// - Index 0: The leaf certificate
    /// - Subsequent indices: Intermediate certificates
    /// - Last index: The trusted root certificate
    public let chain: [Certificate]?

    /// The validation error, if validation failed.
    public let error: ChainValidationError?

    /// Creates a successful validation result.
    ///
    /// - Parameter chain: The validated certificate chain.
    public static func success(chain: [Certificate]) -> ChainValidationResult {
        return ChainValidationResult(isValid: true, chain: chain, error: nil)
    }

    /// Creates a failed validation result.
    ///
    /// - Parameter error: The validation error.
    public static func failure(_ error: ChainValidationError) -> ChainValidationResult {
        return ChainValidationResult(isValid: false, chain: nil, error: error)
    }

    private init(isValid: Bool, chain: [Certificate]?, error: ChainValidationError?) {
        self.isValid = isValid
        self.chain = chain
        self.error = error
    }
}

/// Errors that can occur during certificate chain validation.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public enum ChainValidationError: Error, Sendable, CustomStringConvertible {
    /// No trusted root certificate could be found for the chain.
    case noTrustAnchor

    /// The certificate has expired.
    case expired(certificate: String, expiredAt: Date)

    /// The certificate is not yet valid.
    case notYetValid(certificate: String, validFrom: Date)

    /// The certificate signature is invalid.
    case invalidSignature(certificate: String, reason: String)

    /// Failed to build a valid certificate path.
    case pathBuildingFailed(String)

    /// The certificate has been revoked.
    case revoked(certificate: String)

    /// A required extension is missing or invalid.
    case invalidExtension(certificate: String, extension: String, reason: String)

    /// The key usage does not permit the intended use.
    case invalidKeyUsage(certificate: String, requiredUsage: String)

    /// The certificate name does not match the expected name.
    case nameMismatch(certificate: String, expectedName: String)

    /// A general validation error.
    case validationFailed(String)

    public var description: String {
        switch self {
        case .noTrustAnchor:
            return "No trusted root certificate found"
        case .expired(let cert, let date):
            return "Certificate '\(cert)' expired at \(date)"
        case .notYetValid(let cert, let date):
            return "Certificate '\(cert)' not valid until \(date)"
        case .invalidSignature(let cert, let reason):
            return "Invalid signature on '\(cert)': \(reason)"
        case .pathBuildingFailed(let reason):
            return "Failed to build certificate path: \(reason)"
        case .revoked(let cert):
            return "Certificate '\(cert)' has been revoked"
        case .invalidExtension(let cert, let ext, let reason):
            return "Invalid extension '\(ext)' on '\(cert)': \(reason)"
        case .invalidKeyUsage(let cert, let usage):
            return "Certificate '\(cert)' does not permit \(usage)"
        case .nameMismatch(let cert, let expected):
            return "Certificate '\(cert)' name does not match '\(expected)'"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        }
    }

    /// A localized description of the error.
    public var localizedDescription: String {
        return description
    }
}
