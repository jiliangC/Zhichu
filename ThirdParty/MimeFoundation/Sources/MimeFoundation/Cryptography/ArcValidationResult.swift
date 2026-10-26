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
// ArcValidationResult.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// The result of an ARC signature validation.
///
/// Represents the outcome of validating an ARC-Message-Signature or ARC-Seal header.
public enum ArcSignatureValidationResult: Sendable {
    /// No signatures to validate.
    case none
    /// The signature validation passed.
    case pass
    /// The signature validation failed.
    case fail
}

/// Errors that can occur during ARC chain validation.
///
/// This option set represents the various types of validation errors that can occur
/// when verifying an ARC chain. Multiple errors can be combined to represent all
/// issues found during validation.
public struct ArcValidationErrors: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Duplicate ARC-Authentication-Results header at the same instance.
    public static let duplicateArcAuthenticationResults = ArcValidationErrors(rawValue: 1 << 0)

    /// Duplicate ARC-Message-Signature header at the same instance.
    public static let duplicateArcMessageSignature = ArcValidationErrors(rawValue: 1 << 1)

    /// Duplicate ARC-Seal header at the same instance.
    public static let duplicateArcSeal = ArcValidationErrors(rawValue: 1 << 2)

    /// Missing ARC-Authentication-Results header for an instance.
    public static let missingArcAuthenticationResults = ArcValidationErrors(rawValue: 1 << 3)

    /// Missing ARC-Message-Signature header for an instance.
    public static let missingArcMessageSignature = ArcValidationErrors(rawValue: 1 << 4)

    /// Missing ARC-Seal header for an instance.
    public static let missingArcSeal = ArcValidationErrors(rawValue: 1 << 5)

    /// The ARC-Authentication-Results header is invalid or malformed.
    public static let invalidArcAuthenticationResults = ArcValidationErrors(rawValue: 1 << 6)

    /// The ARC-Message-Signature header is invalid or malformed.
    public static let invalidArcMessageSignature = ArcValidationErrors(rawValue: 1 << 7)

    /// The ARC-Seal header is invalid or malformed.
    public static let invalidArcSeal = ArcValidationErrors(rawValue: 1 << 8)

    /// The ARC-Seal chain validation (cv) value is invalid.
    public static let invalidArcSealChainValidationValue = ArcValidationErrors(rawValue: 1 << 9)

    /// The ARC-Seal chain validation (cv) value is missing.
    public static let missingArcSealChainValidationValue = ArcValidationErrors(rawValue: 1 << 10)

    /// The ARC-Message-Signature validation failed.
    public static let messageSignatureValidationFailed = ArcValidationErrors(rawValue: 1 << 11)

    /// The ARC-Seal validation failed.
    public static let sealValidationFailed = ArcValidationErrors(rawValue: 1 << 12)
}

/// The result of validating a single ARC header.
///
/// Contains the header that was validated along with its validation result.
public struct ArcHeaderValidationResult {
    /// The ARC header that was validated.
    public let header: Header

    /// The result of the signature validation.
    public let signature: ArcSignatureValidationResult

    /// Creates a new ARC header validation result.
    ///
    /// - Parameters:
    ///   - header: The header that was validated.
    ///   - signature: The validation result.
    public init(header: Header, signature: ArcSignatureValidationResult) {
        self.header = header
        self.signature = signature
    }
}

/// The result of validating an ARC chain.
///
/// Contains the complete results of validating all ARC headers in a message,
/// including the ARC-Message-Signature, all ARC-Seals, and the overall chain status.
public struct ArcValidationResult {
    /// The result of validating the ARC-Message-Signature header.
    public let messageSignature: ArcHeaderValidationResult?

    /// The results of validating all ARC-Seal headers.
    public let seals: [ArcHeaderValidationResult]

    /// The overall chain validation result.
    public let chain: ArcSignatureValidationResult

    /// The errors encountered during chain validation.
    public let chainErrors: ArcValidationErrors

    /// Creates a new ARC validation result.
    ///
    /// - Parameters:
    ///   - messageSignature: The ARC-Message-Signature validation result.
    ///   - seals: The ARC-Seal validation results.
    ///   - chain: The overall chain validation result.
    ///   - chainErrors: Any errors encountered during validation.
    public init(messageSignature: ArcHeaderValidationResult?, seals: [ArcHeaderValidationResult], chain: ArcSignatureValidationResult, chainErrors: ArcValidationErrors) {
        self.messageSignature = messageSignature
        self.seals = seals
        self.chain = chain
        self.chainErrors = chainErrors
    }

    /// Creates an empty ARC validation result indicating no ARC headers were found.
    public static var none: ArcValidationResult {
        ArcValidationResult(messageSignature: nil, seals: [], chain: .none, chainErrors: [])
    }
}
