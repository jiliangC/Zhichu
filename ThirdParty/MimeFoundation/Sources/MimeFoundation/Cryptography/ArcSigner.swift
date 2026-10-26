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
// ArcSigner.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An abstract ARC signer for creating ARC signatures on email messages.
///
/// ARC (Authenticated Received Chain) allows intermediaries like mailing lists
/// and forwarders to sign messages in a way that preserves the original
/// authentication results. This is specified in RFC 8617.
///
/// ## Subclassing
///
/// This is an abstract class. You must subclass and override
/// ``generateArcAuthenticationResults(options:message:)`` to provide the
/// authentication results that should be included in the ARC-Authentication-Results
/// header.
///
/// ```swift
/// final class MyArcSigner: ArcSigner {
///     let serviceIdentifier: String
///
///     init(privateKey: DkimPrivateKey, domain: String, selector: String, serviceIdentifier: String) throws {
///         self.serviceIdentifier = serviceIdentifier
///         try super.init(privateKey: privateKey, domain: domain, selector: selector)
///     }
///
///     override func generateArcAuthenticationResults(options: FormatOptions, message: MimeMessage) -> AuthenticationResults? {
///         let results = AuthenticationResults(serviceIdentifier)
///         // Add authentication results...
///         return results
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Signing Messages
/// - ``sign(options:message:headers:)``
/// - ``sign(message:headers:)``
/// - ``sign(options:message:headers:)-2lxrx``
/// - ``sign(message:headers:)-3u7g5``
/// - ``signAsync(options:message:headers:)``
/// - ``signAsync(message:headers:)``
///
/// ### Abstract Methods
/// - ``generateArcAuthenticationResults(options:message:)``
/// - ``generateArcAuthenticationResultsAsync(options:message:)``
open class ArcSigner: DkimSignerBase {
    /// Headers that should not be included in the ARC-Message-Signature.
    ///
    /// These headers may be modified by intermediaries or are signature-related
    /// headers that shouldn't be signed.
    public static let arcShouldNotInclude: Set<String> = [
        "return-path",
        "received",
        "comments",
        "keywords",
        "bcc",
        "resent-bcc",
        "arc-authentication-results",
        "arc-message-signature",
        "arc-seal"
    ]

    /// Generates the ARC-Authentication-Results header content.
    ///
    /// Subclasses must override this method to provide the authentication
    /// results that should be included in the ARC chain.
    ///
    /// - Parameters:
    ///   - options: The formatting options.
    ///   - message: The message being signed.
    /// - Returns: The authentication results, or `nil` if signing should be skipped.
    ///
    /// ## Implementation Notes
    ///
    /// The returned `AuthenticationResults` should include:
    /// - The authentication service identifier for your service
    /// - Results from SPF, DKIM, DMARC, or other authentication checks
    ///
    /// The `instance` property will be set automatically by the signer.
    open func generateArcAuthenticationResults(options: FormatOptions, message: MimeMessage) -> AuthenticationResults? {
        fatalError("Subclasses must override generateArcAuthenticationResults(options:message:)")
    }

    /// Asynchronously generates the ARC-Authentication-Results header content.
    ///
    /// The default implementation calls ``generateArcAuthenticationResults(options:message:)``.
    /// Override this method for async implementations.
    ///
    /// - Parameters:
    ///   - options: The formatting options.
    ///   - message: The message being signed.
    /// - Returns: The authentication results, or `nil` if signing should be skipped.
    open func generateArcAuthenticationResultsAsync(options: FormatOptions, message: MimeMessage) async -> AuthenticationResults? {
        generateArcAuthenticationResults(options: options, message: message)
    }

    /// Gets the current timestamp as Unix time.
    ///
    /// Override this method in tests to provide a fixed timestamp.
    ///
    /// - Returns: The current Unix timestamp.
    open func getTimestamp() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }

    /// Signs the message with ARC headers.
    ///
    /// This method:
    /// 1. Reads any existing ARC chain from the message
    /// 2. Generates the ARC-Authentication-Results header
    /// 3. Generates the ARC-Message-Signature header
    /// 4. Generates the ARC-Seal header
    /// 5. Inserts all three headers at the top of the message
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - message: The message to sign.
    ///   - headers: The list of header field names to sign.
    /// - Throws: ``DkimSignerError`` if signing fails.
    public func sign(options: FormatOptions, message: MimeMessage, headers: [String]) throws {
        let fields = try validateHeaderFields(headers)
        try arcSign(options, message: message, headers: fields)
    }

    /// Signs the message with ARC headers using default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - headers: The list of header field names to sign.
    /// - Throws: ``DkimSignerError`` if signing fails.
    public func sign(message: MimeMessage, headers: [String]) throws {
        try sign(options: .default, message: message, headers: headers)
    }

    /// Signs the message with ARC headers.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - message: The message to sign.
    ///   - headers: The list of header identifiers to sign.
    /// - Throws: ``DkimSignerError`` if signing fails.
    public func sign(options: FormatOptions, message: MimeMessage, headers: [HeaderId]) throws {
        let fields = try validateHeaderIds(headers)
        try arcSign(options, message: message, headers: fields)
    }

    /// Signs the message with ARC headers using default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - headers: The list of header identifiers to sign.
    /// - Throws: ``DkimSignerError`` if signing fails.
    public func sign(message: MimeMessage, headers: [HeaderId]) throws {
        try sign(options: .default, message: message, headers: headers)
    }

    /// Asynchronously signs the message with ARC headers.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - message: The message to sign.
    ///   - headers: The list of header field names to sign.
    /// - Throws: ``DkimSignerError`` if signing fails, or `CancellationError` if cancelled.
    public func signAsync(options: FormatOptions, message: MimeMessage, headers: [String]) async throws {
        let fields = try validateHeaderFields(headers)
        try await arcSignAsync(options, message: message, headers: fields)
    }

    /// Asynchronously signs the message with ARC headers using default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - headers: The list of header field names to sign.
    /// - Throws: ``DkimSignerError`` if signing fails, or `CancellationError` if cancelled.
    public func signAsync(message: MimeMessage, headers: [String]) async throws {
        try await signAsync(options: .default, message: message, headers: headers)
    }

    /// Asynchronously signs the message with ARC headers.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use.
    ///   - message: The message to sign.
    ///   - headers: The list of header identifiers to sign.
    /// - Throws: ``DkimSignerError`` if signing fails, or `CancellationError` if cancelled.
    public func signAsync(options: FormatOptions, message: MimeMessage, headers: [HeaderId]) async throws {
        let fields = try validateHeaderIds(headers)
        try await arcSignAsync(options, message: message, headers: fields)
    }

    /// Asynchronously signs the message with ARC headers using default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - headers: The list of header identifiers to sign.
    /// - Throws: ``DkimSignerError`` if signing fails, or `CancellationError` if cancelled.
    public func signAsync(message: MimeMessage, headers: [HeaderId]) async throws {
        try await signAsync(options: .default, message: message, headers: headers)
    }

    // MARK: - Private Implementation

    private func validateHeaderFields(_ headers: [String]) throws -> [String] {
        var fields: [String] = []
        fields.reserveCapacity(headers.count)

        for header in headers {
            guard !header.isEmpty else {
                throw DkimSignerError.invalidArgument
            }
            let field = header.lowercased()
            if ArcSigner.arcShouldNotInclude.contains(field) {
                throw DkimSignerError.invalidArgument
            }
            fields.append(field)
        }

        return fields
    }

    private func validateHeaderIds(_ headers: [HeaderId]) throws -> [String] {
        var fields: [String] = []
        fields.reserveCapacity(headers.count)

        for header in headers {
            if header == .unknown {
                throw DkimSignerError.invalidArgument
            }
            let field = header.headerName.lowercased()
            if ArcSigner.arcShouldNotInclude.contains(field) {
                throw DkimSignerError.invalidArgument
            }
            fields.append(field)
        }

        return fields
    }

    private func arcSign(_ options: FormatOptions, message: MimeMessage, headers: [String]) throws {
        var signingOptions = options.copy()
        signingOptions.newLineFormat = .dos
        signingOptions.ensureNewLine = true

        // Get existing ARC chain info
        let existingChain = try ArcVerifier.getArcHeaderSets(message: message, throwOnError: false)
        let instance = existingChain.count + 1

        // Determine chain validation value
        let cv: String
        if instance == 1 {
            cv = "none"
        } else if existingChain.result == .fail || !existingChain.errors.isEmpty {
            cv = "fail"
        } else {
            cv = "pass"
        }

        // Generate ARC-Authentication-Results
        guard var authResults = generateArcAuthenticationResults(options: signingOptions, message: message) else {
            return
        }
        authResults.instance = instance

        let aarHeader = Header(.arcAuthenticationResults, value: authResults.toString())

        // Generate ARC-Message-Signature
        let amsHeader = try generateArcMessageSignature(options: signingOptions, message: message, headers: headers, instance: instance)

        // Generate ARC-Seal
        let asHeader = try generateArcSeal(options: signingOptions, message: message, aarHeader: aarHeader, amsHeader: amsHeader, existingChain: existingChain.sets, instance: instance, cv: cv)

        // Insert headers in reverse order so they appear as: AS, AMS, AAR
        message.headers.insert(asHeader, at: 0)
        message.headers.insert(amsHeader, at: 0)
        message.headers.insert(aarHeader, at: 0)
    }

    private func arcSignAsync(_ options: FormatOptions, message: MimeMessage, headers: [String]) async throws {
        try Task.checkCancellation()

        var signingOptions = options.copy()
        signingOptions.newLineFormat = .dos
        signingOptions.ensureNewLine = true

        // Get existing ARC chain info
        let existingChain = try ArcVerifier.getArcHeaderSets(message: message, throwOnError: false)
        let instance = existingChain.count + 1

        // Determine chain validation value
        let cv: String
        if instance == 1 {
            cv = "none"
        } else if existingChain.result == .fail || !existingChain.errors.isEmpty {
            cv = "fail"
        } else {
            cv = "pass"
        }

        // Generate ARC-Authentication-Results
        guard var authResults = await generateArcAuthenticationResultsAsync(options: signingOptions, message: message) else {
            return
        }
        authResults.instance = instance

        let aarHeader = Header(.arcAuthenticationResults, value: authResults.toString())

        // Generate ARC-Message-Signature
        let amsHeader = try generateArcMessageSignature(options: signingOptions, message: message, headers: headers, instance: instance)

        // Generate ARC-Seal
        let asHeader = try generateArcSeal(options: signingOptions, message: message, aarHeader: aarHeader, amsHeader: amsHeader, existingChain: existingChain.sets, instance: instance, cv: cv)

        // Insert headers in reverse order so they appear as: AS, AMS, AAR
        message.headers.insert(asHeader, at: 0)
        message.headers.insert(amsHeader, at: 0)
        message.headers.insert(aarHeader, at: 0)
    }

    private func generateArcMessageSignature(options: FormatOptions, message: MimeMessage, headers: [String], instance: Int) throws -> Header {
        var builder = ValueStringBuilder(initialCapacity: 256)
        let timestamp = getTimestamp()

        builder.append("i=")
        builder.append(String(instance))

        switch signatureAlgorithm {
        case .ed25519Sha256:
            builder.append("; a=ed25519-sha256")
        case .rsaSha256:
            builder.append("; a=rsa-sha256")
        case .rsaSha1:
            builder.append("; a=rsa-sha1")
        }

        builder.append("; d=")
        builder.append(domain)
        builder.append("; s=")
        builder.append(selector)
        builder.append("; c=")
        builder.append(canonicalizationToken(headerCanonicalizationAlgorithm))
        builder.append("/")
        builder.append(canonicalizationToken(bodyCanonicalizationAlgorithm))
        builder.append("; t=")
        builder.append(String(timestamp))

        if let expiresAfter = signaturesExpireAfter {
            let expiration = timestamp + Int64(expiresAfter)
            builder.append("; x=")
            builder.append(String(expiration))
        }

        let context = try createSigningContext()
        let stream = try DkimSignatureStream(context)
        let filtered = try FilteredStream(stream)
        try filtered.add(options.createNewLineFilter(false))

        try DkimVerifierBase.writeHeaders(options: options, message: message, fields: headers, canonicalization: headerCanonicalizationAlgorithm, stream: filtered)

        builder.append("; h=")
        builder.appendJoin(separator: ":", values: headers)

        let bodyHash = try message.hashBody(options, signatureAlgorithm: signatureAlgorithm, bodyCanonicalization: bodyCanonicalizationAlgorithm, maxLength: -1)
        builder.append("; bh=")
        builder.append(Data(bodyHash).base64EncodedString())
        builder.append("; b=")

        let amsHeader = Header(.arcMessageSignature, value: builder.toString())

        switch headerCanonicalizationAlgorithm {
        case .relaxed:
            try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: amsHeader, isDkimSignature: true)
        case .simple:
            try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: amsHeader, isDkimSignature: true)
        }

        try filtered.flush()

        let signature = try stream.generateSignature()
        amsHeader.value += Data(signature).base64EncodedString()

        return amsHeader
    }

    private func generateArcSeal(options: FormatOptions, message: MimeMessage, aarHeader: Header, amsHeader: Header, existingChain: [ArcHeaderSet], instance: Int, cv: String) throws -> Header {
        var builder = ValueStringBuilder(initialCapacity: 256)
        let timestamp = getTimestamp()

        builder.append("i=")
        builder.append(String(instance))

        switch signatureAlgorithm {
        case .ed25519Sha256:
            builder.append("; a=ed25519-sha256")
        case .rsaSha256:
            builder.append("; a=rsa-sha256")
        case .rsaSha1:
            builder.append("; a=rsa-sha1")
        }

        builder.append("; d=")
        builder.append(domain)
        builder.append("; s=")
        builder.append(selector)
        builder.append("; c=")
        builder.append(canonicalizationToken(headerCanonicalizationAlgorithm))
        builder.append("; cv=")
        builder.append(cv)
        builder.append("; t=")
        builder.append(String(timestamp))
        builder.append("; b=")

        let asHeader = Header(.arcSeal, value: builder.toString())

        // Create signature over the ARC chain
        let context = try createSigningContext()
        let stream = try DkimSignatureStream(context)
        let filtered = try FilteredStream(stream)
        try filtered.add(options.createNewLineFilter(false))

        // Write all existing ARC headers
        for set in existingChain {
            if let aar = set.arcAuthenticationResults {
                switch headerCanonicalizationAlgorithm {
                case .relaxed:
                    try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: aar, isDkimSignature: false)
                case .simple:
                    try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: aar, isDkimSignature: false)
                }
            }
            if let ams = set.arcMessageSignature {
                switch headerCanonicalizationAlgorithm {
                case .relaxed:
                    try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: ams, isDkimSignature: false)
                case .simple:
                    try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: ams, isDkimSignature: false)
                }
            }
            if let seal = set.arcSeal {
                switch headerCanonicalizationAlgorithm {
                case .relaxed:
                    try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: seal, isDkimSignature: false)
                case .simple:
                    try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: seal, isDkimSignature: false)
                }
            }
        }

        // Write the new AAR and AMS headers
        switch headerCanonicalizationAlgorithm {
        case .relaxed:
            try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: aarHeader, isDkimSignature: false)
            try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: amsHeader, isDkimSignature: false)
            try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: asHeader, isDkimSignature: true)
        case .simple:
            try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: aarHeader, isDkimSignature: false)
            try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: amsHeader, isDkimSignature: false)
            try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: asHeader, isDkimSignature: true)
        }

        try filtered.flush()

        let signature = try stream.generateSignature()
        asHeader.value += Data(signature).base64EncodedString()

        return asHeader
    }

    private func canonicalizationToken(_ algorithm: DkimCanonicalizationAlgorithm) -> String {
        switch algorithm {
        case .relaxed:
            return "relaxed"
        case .simple:
            return "simple"
        }
    }
}
