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
// ArcVerifier.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during ARC verification operations.
public enum ArcVerifierError: Error, Equatable, Sendable {
    /// An invalid argument was provided.
    case invalidArgument
    /// The ARC header is malformed and cannot be parsed.
    case malformedHeader(String)
    /// The signature algorithm is not supported or not enabled.
    case unsupportedAlgorithm
    /// The public key is invalid or incompatible with the signature algorithm.
    case invalidKey
}

/// An ARC chain verifier.
///
/// Verifies Authenticated Received Chain (ARC) signatures as specified in RFC 8617.
///
/// ARC provides a way for a receiver of an email to preserve the authentication
/// results of previous intermediaries, allowing downstream receivers to verify
/// the original authentication even after the message has been modified by
/// mailing lists or forwarders.
///
/// ## Usage
///
/// ```swift
/// // Create a verifier with a public key locator
/// let locator = MyDkimPublicKeyLocator()
/// let verifier = ArcVerifier(publicKeyLocator: locator)
///
/// // Verify the ARC chain
/// let result = try verifier.verify(message: message)
/// switch result.chain {
/// case .none:
///     print("No ARC chain found")
/// case .pass:
///     print("ARC chain is valid")
/// case .fail:
///     print("ARC chain failed validation")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Verifier
/// - ``init(publicKeyLocator:)``
///
/// ### Verifying ARC Chains
/// - ``verify(options:message:)``
/// - ``verify(message:)``
/// - ``verifyAsync(options:message:)``
/// - ``verifyAsync(message:)``
///
/// ### Parsing ARC Headers
/// - ``getArcHeaderSets(message:throwOnError:)``
public final class ArcVerifier: DkimVerifierBase {
    /// The result of parsing ARC headers from a message.
    public typealias ArcHeaderSetsResult = (sets: [ArcHeaderSet], count: Int, errors: ArcValidationErrors, result: ArcSignatureValidationResult)

    /// Creates a new ARC verifier with the specified public key locator.
    ///
    /// - Parameter publicKeyLocator: The service used to retrieve public keys for
    ///   signature verification. This is typically implemented using DNS lookups.
    public override init(publicKeyLocator: DkimPublicKeyLocator) {
        super.init(publicKeyLocator: publicKeyLocator)
    }

    /// Parses and validates ARC headers from a message.
    ///
    /// This method extracts all ARC headers from the message and organizes them
    /// by instance number. It validates the basic structure of the ARC chain,
    /// including:
    /// - Checking for duplicate headers at the same instance
    /// - Verifying that instance numbers form a contiguous sequence starting at 1
    /// - Validating the `cv` (chain validation) tag values
    ///
    /// - Parameters:
    ///   - message: The message to parse.
    ///   - throwOnError: If `true`, throws on parsing errors; otherwise, returns errors in the result.
    /// - Returns: A tuple containing the parsed header sets, count, any validation errors, and the chain result.
    /// - Throws: ``DkimVerifierError`` if `throwOnError` is true and a parsing error occurs.
    public static func getArcHeaderSets(message: MimeMessage, throwOnError: Bool = false) throws -> ArcHeaderSetsResult {
        var sets: [ArcHeaderSet] = []
        var errors: ArcValidationErrors = []
        var maxInstance = 0

        for header in message.headers {
            var instance: Int?
            var parameters: [String: String]?

            switch header.id {
            case .arcAuthenticationResults:
                // Parse AAR to get instance
                do {
                    let authres = try AuthenticationResults(parsing: header.value)
                    instance = authres.instance
                } catch {
                    errors.insert(.invalidArcAuthenticationResults)
                    if throwOnError {
                        throw DkimVerifierError.malformedHeader("Invalid ARC-Authentication-Results header: \(error)")
                    }
                    continue
                }

                if instance == nil {
                    errors.insert(.invalidArcAuthenticationResults)
                    if throwOnError {
                        throw DkimVerifierError.malformedHeader("ARC-Authentication-Results header is missing instance (i=) parameter.")
                    }
                    continue
                }

            case .arcMessageSignature:
                // Parse AMS parameters to get instance
                do {
                    parameters = try DkimVerifierBase.parseParameterTags(headerId: .arcMessageSignature, signature: header.value)
                } catch {
                    errors.insert(.invalidArcMessageSignature)
                    if throwOnError {
                        throw error
                    }
                    continue
                }

                guard let iValue = parameters?["i"], let i = Int(iValue), i > 0 else {
                    errors.insert(.invalidArcMessageSignature)
                    if throwOnError {
                        throw DkimVerifierError.malformedHeader("ARC-Message-Signature header has invalid instance (i=) parameter.")
                    }
                    continue
                }
                instance = i

            case .arcSeal:
                // Parse AS parameters to get instance and validate cv
                do {
                    parameters = try DkimVerifierBase.parseParameterTags(headerId: .arcSeal, signature: header.value)
                } catch {
                    errors.insert(.invalidArcSeal)
                    if throwOnError {
                        throw error
                    }
                    continue
                }

                guard let iValue = parameters?["i"], let i = Int(iValue), i > 0 else {
                    errors.insert(.invalidArcSeal)
                    if throwOnError {
                        throw DkimVerifierError.malformedHeader("ARC-Seal header has invalid instance (i=) parameter.")
                    }
                    continue
                }
                instance = i

                // Validate cv tag
                guard let cv = parameters?["cv"] else {
                    errors.insert(.missingArcSealChainValidationValue)
                    if throwOnError {
                        throw DkimVerifierError.malformedHeader("ARC-Seal header is missing chain validation (cv=) parameter.")
                    }
                    continue
                }

                let cvLower = cv.lowercased()
                if cvLower != "none" && cvLower != "pass" && cvLower != "fail" {
                    errors.insert(.invalidArcSealChainValidationValue)
                    if throwOnError {
                        throw DkimVerifierError.malformedHeader("ARC-Seal header has invalid chain validation (cv=\(cv)) value.")
                    }
                    continue
                }

                // Check cv value validity based on instance number
                if i == 1 {
                    if cvLower != "none" {
                        errors.insert(.invalidArcSealChainValidationValue)
                        if throwOnError {
                            throw DkimVerifierError.malformedHeader("ARC-Seal instance 1 must have cv=none, but found cv=\(cv).")
                        }
                    }
                } else {
                    if cvLower != "pass" {
                        // cv=fail indicates a broken chain - this is an error
                        if cvLower == "fail" {
                            return (sets: sets, count: maxInstance, errors: errors, result: .fail)
                        }
                        errors.insert(.invalidArcSealChainValidationValue)
                        if throwOnError {
                            throw DkimVerifierError.malformedHeader("ARC-Seal instance \(i) must have cv=pass, but found cv=\(cv).")
                        }
                    }
                }

            default:
                continue
            }

            guard let inst = instance else {
                continue
            }

            // Ensure sets array is large enough
            while sets.count < inst {
                sets.append(ArcHeaderSet())
            }

            let setIndex = inst - 1
            if !sets[setIndex].add(header: header, parameters: parameters) {
                // Duplicate header
                switch header.id {
                case .arcAuthenticationResults:
                    errors.insert(.duplicateArcAuthenticationResults)
                case .arcMessageSignature:
                    errors.insert(.duplicateArcMessageSignature)
                case .arcSeal:
                    errors.insert(.duplicateArcSeal)
                default:
                    break
                }
                if throwOnError {
                    throw DkimVerifierError.malformedHeader("Duplicate \(header.field) header for instance \(inst).")
                }
            }

            maxInstance = max(maxInstance, inst)
        }

        // Check for missing headers in each set
        for i in 0..<sets.count {
            let missingErrors = sets[i].missingHeaderErrors
            if !missingErrors.isEmpty {
                errors.formUnion(missingErrors)
            }
        }

        let result: ArcSignatureValidationResult = sets.isEmpty ? .none : .pass
        return (sets: sets, count: maxInstance, errors: errors, result: result)
    }

    /// Verifies the ARC chain in a message.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use when canonicalizing the message.
    ///   - message: The message to verify.
    /// - Returns: The ARC validation result containing the chain status and any errors.
    /// - Throws: ``DkimVerifierError`` if a critical parsing error occurs.
    public func verify(options: FormatOptions, message: MimeMessage) throws -> ArcValidationResult {
        var options = options.copy()
        options.newLineFormat = .dos

        let headerSets = try ArcVerifier.getArcHeaderSets(message: message, throwOnError: false)

        if headerSets.count == 0 {
            return .none
        }

        if headerSets.result == .fail || !headerSets.errors.isEmpty {
            return ArcValidationResult(messageSignature: nil, seals: [], chain: .fail, chainErrors: headerSets.errors)
        }

        var seals: [ArcHeaderValidationResult] = []
        var chainErrors = headerSets.errors
        var chainResult: ArcSignatureValidationResult = .pass

        // Verify the most recent ARC-Message-Signature (highest instance)
        let latestIndex = headerSets.count - 1
        let latestSet = headerSets.sets[latestIndex]

        var messageSignatureResult: ArcHeaderValidationResult?
        if let amsHeader = latestSet.arcMessageSignature,
           let amsParams = latestSet.arcMessageSignatureParameters {
            let amsValid = try verifyArcMessageSignature(options: options, message: message, header: amsHeader, parameters: amsParams)
            messageSignatureResult = ArcHeaderValidationResult(header: amsHeader, signature: amsValid ? .pass : .fail)
            if !amsValid {
                chainErrors.insert(.messageSignatureValidationFailed)
                chainResult = .fail
            }
        } else {
            chainResult = .fail
        }

        // Verify all ARC-Seals from oldest to newest
        for i in 0..<headerSets.count {
            let set = headerSets.sets[i]
            guard let asHeader = set.arcSeal,
                  let asParams = set.arcSealParameters else {
                continue
            }

            let asValid = try verifyArcSeal(options: options, message: message, header: asHeader, parameters: asParams, headerSets: headerSets.sets, instance: i + 1)
            seals.append(ArcHeaderValidationResult(header: asHeader, signature: asValid ? .pass : .fail))
            if !asValid {
                chainErrors.insert(.sealValidationFailed)
                chainResult = .fail
            }
        }

        return ArcValidationResult(messageSignature: messageSignatureResult, seals: seals, chain: chainResult, chainErrors: chainErrors)
    }

    /// Verifies the ARC chain in a message using default formatting options.
    ///
    /// - Parameter message: The message to verify.
    /// - Returns: The ARC validation result.
    /// - Throws: ``DkimVerifierError`` if a critical parsing error occurs.
    public func verify(message: MimeMessage) throws -> ArcValidationResult {
        try verify(options: .default, message: message)
    }

    /// Asynchronously verifies the ARC chain in a message.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use when canonicalizing the message.
    ///   - message: The message to verify.
    /// - Returns: The ARC validation result.
    /// - Throws: ``DkimVerifierError`` if a critical parsing error occurs, or `CancellationError` if cancelled.
    public func verifyAsync(options: FormatOptions, message: MimeMessage) async throws -> ArcValidationResult {
        try Task.checkCancellation()

        var options = options.copy()
        options.newLineFormat = .dos

        let headerSets = try ArcVerifier.getArcHeaderSets(message: message, throwOnError: false)

        if headerSets.count == 0 {
            return .none
        }

        if headerSets.result == .fail || !headerSets.errors.isEmpty {
            return ArcValidationResult(messageSignature: nil, seals: [], chain: .fail, chainErrors: headerSets.errors)
        }

        var seals: [ArcHeaderValidationResult] = []
        var chainErrors = headerSets.errors
        var chainResult: ArcSignatureValidationResult = .pass

        // Verify the most recent ARC-Message-Signature (highest instance)
        let latestIndex = headerSets.count - 1
        let latestSet = headerSets.sets[latestIndex]

        var messageSignatureResult: ArcHeaderValidationResult?
        if let amsHeader = latestSet.arcMessageSignature,
           let amsParams = latestSet.arcMessageSignatureParameters {
            let amsValid = try await verifyArcMessageSignatureAsync(options: options, message: message, header: amsHeader, parameters: amsParams)
            messageSignatureResult = ArcHeaderValidationResult(header: amsHeader, signature: amsValid ? .pass : .fail)
            if !amsValid {
                chainErrors.insert(.messageSignatureValidationFailed)
                chainResult = .fail
            }
        } else {
            chainResult = .fail
        }

        // Verify all ARC-Seals from oldest to newest
        for i in 0..<headerSets.count {
            try Task.checkCancellation()
            let set = headerSets.sets[i]
            guard let asHeader = set.arcSeal,
                  let asParams = set.arcSealParameters else {
                continue
            }

            let asValid = try await verifyArcSealAsync(options: options, message: message, header: asHeader, parameters: asParams, headerSets: headerSets.sets, instance: i + 1)
            seals.append(ArcHeaderValidationResult(header: asHeader, signature: asValid ? .pass : .fail))
            if !asValid {
                chainErrors.insert(.sealValidationFailed)
                chainResult = .fail
            }
        }

        return ArcValidationResult(messageSignature: messageSignatureResult, seals: seals, chain: chainResult, chainErrors: chainErrors)
    }

    /// Asynchronously verifies the ARC chain in a message using default formatting options.
    ///
    /// - Parameter message: The message to verify.
    /// - Returns: The ARC validation result.
    /// - Throws: ``DkimVerifierError`` if a critical parsing error occurs, or `CancellationError` if cancelled.
    public func verifyAsync(message: MimeMessage) async throws -> ArcValidationResult {
        try await verifyAsync(options: .default, message: message)
    }

    // MARK: - Private Verification Methods

    private func verifyArcMessageSignature(options: FormatOptions, message: MimeMessage, header: Header, parameters: [String: String]) throws -> Bool {
        let validated = try validateArcMessageSignatureParameters(parameters)

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

        return try verifySignature(options: options, message: message, dkimSignature: header, signatureAlgorithm: validated.algorithm, key: key, headers: validated.headers, canonicalizationAlgorithm: validated.headerAlgorithm, signature: validated.b)
    }

    private func verifyArcMessageSignatureAsync(options: FormatOptions, message: MimeMessage, header: Header, parameters: [String: String]) async throws -> Bool {
        let validated = try validateArcMessageSignatureParameters(parameters)

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

        return try verifySignature(options: options, message: message, dkimSignature: header, signatureAlgorithm: validated.algorithm, key: key, headers: validated.headers, canonicalizationAlgorithm: validated.headerAlgorithm, signature: validated.b)
    }

    private func verifyArcSeal(options: FormatOptions, message: MimeMessage, header: Header, parameters: [String: String], headerSets: [ArcHeaderSet], instance: Int) throws -> Bool {
        let validated = try validateArcSealParameters(parameters)

        if !isEnabled(validated.algorithm) {
            return false
        }

        let key = try locatePublicKey(methods: validated.q, domain: validated.d, selector: validated.s)

        if case .rsa(let rsa) = key {
            if rsa.keySizeInBits < minimumRsaKeyLength {
                return false
            }
        }

        return try verifyArcSealSignature(options: options, header: header, parameters: parameters, headerSets: headerSets, instance: instance, algorithm: validated.algorithm, canonicalizationAlgorithm: validated.headerAlgorithm, key: key, signature: validated.b)
    }

    private func verifyArcSealAsync(options: FormatOptions, message: MimeMessage, header: Header, parameters: [String: String], headerSets: [ArcHeaderSet], instance: Int) async throws -> Bool {
        let validated = try validateArcSealParameters(parameters)

        if !isEnabled(validated.algorithm) {
            return false
        }

        let key = try await locatePublicKeyAsync(methods: validated.q, domain: validated.d, selector: validated.s)

        if case .rsa(let rsa) = key {
            if rsa.keySizeInBits < minimumRsaKeyLength {
                return false
            }
        }

        return try verifyArcSealSignature(options: options, header: header, parameters: parameters, headerSets: headerSets, instance: instance, algorithm: validated.algorithm, canonicalizationAlgorithm: validated.headerAlgorithm, key: key, signature: validated.b)
    }

    private func verifyArcSealSignature(options: FormatOptions, header: Header, parameters: [String: String], headerSets: [ArcHeaderSet], instance: Int, algorithm: DkimSignatureAlgorithm, canonicalizationAlgorithm: DkimCanonicalizationAlgorithm, key: DkimPublicKey, signature: String) throws -> Bool {
        let context = try createVerifyContext(algorithm, key: key)
        let stream = try DkimSignatureStream(context)
        let filtered = try FilteredStream(stream)
        try filtered.add(options.createNewLineFilter(false))

        // Write ARC headers for all instances up to and including current instance
        for i in 0..<instance {
            let set = headerSets[i]

            // Write ARC-Authentication-Results
            if let aar = set.arcAuthenticationResults {
                switch canonicalizationAlgorithm {
                case .relaxed:
                    try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: aar, isDkimSignature: false)
                case .simple:
                    try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: aar, isDkimSignature: false)
                }
            }

            // Write ARC-Message-Signature
            if let ams = set.arcMessageSignature {
                switch canonicalizationAlgorithm {
                case .relaxed:
                    try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: ams, isDkimSignature: false)
                case .simple:
                    try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: ams, isDkimSignature: false)
                }
            }

            // Write ARC-Seal (with b= stripped for the current instance)
            if let seal = set.arcSeal {
                let isCurrentSeal = (i == instance - 1)
                if isCurrentSeal {
                    let signedHeader = try DkimVerifierBase.getSignedSignatureHeader(seal)
                    switch canonicalizationAlgorithm {
                    case .relaxed:
                        try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: signedHeader, isDkimSignature: true)
                    case .simple:
                        try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: signedHeader, isDkimSignature: true)
                    }
                } else {
                    switch canonicalizationAlgorithm {
                    case .relaxed:
                        try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: seal, isDkimSignature: false)
                    case .simple:
                        try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: seal, isDkimSignature: false)
                    }
                }
            }
        }

        try filtered.flush()
        return try stream.verifySignature(signature)
    }

    // MARK: - Parameter Validation

    private func validateArcMessageSignatureParameters(_ parameters: [String: String]) throws -> (algorithm: DkimSignatureAlgorithm, headerAlgorithm: DkimCanonicalizationAlgorithm, bodyAlgorithm: DkimCanonicalizationAlgorithm, d: String, s: String, q: String, headers: [String], bh: String, b: String, maxLength: Int) {
        let common = try DkimVerifierBase.validateCommonSignatureParameters(header: "ARC-Message-Signature", parameters: parameters)

        // ARC-Message-Signature requires an instance (i=) parameter
        guard let iValue = parameters["i"], let _ = Int(iValue) else {
            throw DkimVerifierError.malformedHeader("Malformed ARC-Message-Signature header: no instance parameter detected.")
        }

        return common
    }

    private func validateArcSealParameters(_ parameters: [String: String]) throws -> (algorithm: DkimSignatureAlgorithm, headerAlgorithm: DkimCanonicalizationAlgorithm, d: String, s: String, q: String, b: String) {
        let common = try DkimVerifierBase.validateCommonParameters(header: "ARC-Seal", parameters: parameters)

        // ARC-Seal requires an instance (i=) parameter
        guard let iValue = parameters["i"], let _ = Int(iValue) else {
            throw DkimVerifierError.malformedHeader("Malformed ARC-Seal header: no instance parameter detected.")
        }

        // ARC-Seal requires a cv (chain validation) parameter
        guard let cv = parameters["cv"] else {
            throw DkimVerifierError.malformedHeader("Malformed ARC-Seal header: no chain validation parameter detected.")
        }

        let cvLower = cv.lowercased()
        if cvLower != "none" && cvLower != "pass" && cvLower != "fail" {
            throw DkimVerifierError.malformedHeader("Malformed ARC-Seal header: invalid chain validation value: cv=\(cv)")
        }

        // Parse canonicalization algorithm (ARC-Seal only has header canonicalization)
        let headerAlgorithm: DkimCanonicalizationAlgorithm
        if let c = parameters["c"] {
            let tokens = c.lowercased().split(separator: "/")
            guard tokens.count >= 1 else {
                throw DkimVerifierError.malformedHeader("Malformed ARC-Seal header: invalid canonicalization parameter: c=\(c)")
            }

            switch tokens[0] {
            case "relaxed":
                headerAlgorithm = .relaxed
            case "simple":
                headerAlgorithm = .simple
            default:
                throw DkimVerifierError.malformedHeader("Malformed ARC-Seal header: invalid canonicalization parameter: c=\(c)")
            }
        } else {
            headerAlgorithm = .simple
        }

        return (common.algorithm, headerAlgorithm, common.d, common.s, common.q, common.b)
    }
}
