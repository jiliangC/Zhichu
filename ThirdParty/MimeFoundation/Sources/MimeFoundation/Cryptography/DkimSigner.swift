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
// DkimSigner.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A DKIM signer for digitally signing email messages.
///
/// Creates DomainKeys Identified Mail (DKIM) signatures as specified in RFC 6376.
/// DKIM provides a method for validating a domain name identity that is associated
/// with a message through cryptographic authentication.
///
/// ## Usage
///
/// ```swift
/// // Create a signer with your private key
/// let signer = try DkimSigner(
///     privateKey: privateKey,
///     domain: "example.com",
///     selector: "selector1",
///     algorithm: .rsaSha256
/// )
///
/// // Sign the message
/// try signer.sign(message, headers: [.from, .to, .subject, .date])
/// ```
///
/// ## Security Considerations
///
/// Due to the recognized weakness of the SHA-1 hash algorithm and the wide
/// availability of SHA-256 (required since DKIM was standardized in 2007),
/// it is recommended that ``DkimSignatureAlgorithm/rsaSha1`` NOT be used.
///
/// ## Topics
///
/// ### Configuration
/// - ``agentOrUserIdentifier``
/// - ``queryMethod``
///
/// ### Signing Messages
/// - ``sign(_:_:headers:)-4h4k5``
/// - ``sign(_:headers:)-1jgq``
/// - ``sign(_:_:headers:)-8n4fz``
/// - ``sign(_:headers:)-5jf1n``
public final class DkimSigner: DkimSignerBase {
    private static let shouldNotInclude: Set<String> = [
        "return-path",
        "received",
        "comments",
        "keywords",
        "bcc",
        "resent-bcc",
        "dkim-signature"
    ]

    /// The agent or user identifier (AUID) for the signature.
    ///
    /// This is an optional identifier that provides additional information about
    /// the signing agent. If set, it will be included in the signature as the
    /// `i=` tag. The domain part of this identifier must match or be a subdomain
    /// of the signing domain.
    ///
    /// For example, if the signing domain is `example.com`, valid values include:
    /// - `user@example.com`
    /// - `@example.com`
    /// - `user@subdomain.example.com`
    public var agentOrUserIdentifier: String?

    /// The public key query method.
    ///
    /// A colon-separated list of query methods used to retrieve the public key
    /// (plain-text; OPTIONAL, default is `"dns/txt"`). Each query method is of
    /// the form `"type[/options]"`, where the syntax and semantics of the options
    /// depend on the type and specified options.
    ///
    /// If set, this value will be included in the signature as the `q=` tag.
    public var queryMethod: String?

    /// Digitally signs the message using a DKIM signature.
    ///
    /// This method signs the specified headers of the message and prepends a
    /// DKIM-Signature header to the message.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use when canonicalizing the message.
    ///   - message: The message to sign.
    ///   - headers: The list of header field names to sign.
    /// - Throws: ``DkimSignerError/invalidArgument`` if the headers list is invalid.
    ///
    /// ## Important
    ///
    /// The headers list:
    /// - MUST include the `"From"` header
    /// - SHOULD NOT include: Return-Path, Received, Comments, Keywords, Bcc,
    ///   Resent-Bcc, or DKIM-Signature
    public func sign(_ options: FormatOptions, _ message: MimeMessage, headers: [String]) throws {
        let fields = try validateHeaderFields(headers)
        try dkimSign(options, message: message, headers: fields)
    }

    /// Digitally signs the message using a DKIM signature with default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - headers: The list of header field names to sign.
    /// - Throws: ``DkimSignerError/invalidArgument`` if the headers list is invalid.
    public func sign(_ message: MimeMessage, headers: [String]) throws {
        try sign(.default, message, headers: headers)
    }

    /// Digitally signs the message using a DKIM signature.
    ///
    /// This method signs the specified headers of the message and prepends a
    /// DKIM-Signature header to the message.
    ///
    /// - Parameters:
    ///   - options: The formatting options to use when canonicalizing the message.
    ///   - message: The message to sign.
    ///   - headers: The list of header identifiers to sign.
    /// - Throws: ``DkimSignerError/invalidArgument`` if the headers list is invalid.
    ///
    /// ## Important
    ///
    /// The headers list:
    /// - MUST include ``HeaderId/from``
    /// - SHOULD NOT include headers that may be modified in transit
    public func sign(_ options: FormatOptions, _ message: MimeMessage, headers: [HeaderId]) throws {
        var fields: [String] = []
        fields.reserveCapacity(headers.count)
        var containsFrom = false

        for header in headers {
            if header == .unknown {
                throw DkimSignerError.invalidArgument
            }
            let field = header.headerName.lowercased()
            if DkimSigner.shouldNotInclude.contains(field) {
                throw DkimSignerError.invalidArgument
            }
            if header == .from {
                containsFrom = true
            }
            fields.append(field)
        }

        guard containsFrom else {
            throw DkimSignerError.invalidArgument
        }

        try dkimSign(options, message: message, headers: fields)
    }

    /// Digitally signs the message using a DKIM signature with default formatting options.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - headers: The list of header identifiers to sign.
    /// - Throws: ``DkimSignerError/invalidArgument`` if the headers list is invalid.
    public func sign(_ message: MimeMessage, headers: [HeaderId]) throws {
        try sign(.default, message, headers: headers)
    }

    private func validateHeaderFields(_ headers: [String]) throws -> [String] {
        var fields: [String] = []
        fields.reserveCapacity(headers.count)
        var containsFrom = false

        for header in headers {
            guard !header.isEmpty else {
                throw DkimSignerError.invalidArgument
            }
            let field = header.lowercased()
            if DkimSigner.shouldNotInclude.contains(field) {
                throw DkimSignerError.invalidArgument
            }
            if field == "from" {
                containsFrom = true
            }
            fields.append(field)
        }

        guard containsFrom else {
            throw DkimSignerError.invalidArgument
        }

        return fields
    }

    private func dkimSign(_ options: FormatOptions, message: MimeMessage, headers: [String]) throws {
        var signingOptions = options.copy()
        signingOptions.newLineFormat = .dos
        signingOptions.ensureNewLine = true

        var builder = ValueStringBuilder(initialCapacity: 256)
        let timestamp = getTimestamp()

        builder.append("v=1")

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

        if let queryMethod, !queryMethod.isEmpty {
            builder.append("; q=")
            builder.append(queryMethod)
        }
        if let agentOrUserIdentifier, !agentOrUserIdentifier.isEmpty {
            builder.append("; i=")
            builder.append(agentOrUserIdentifier)
        }

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
        try filtered.add(signingOptions.createNewLineFilter(false))

        try DkimVerifierBase.writeHeaders(options: signingOptions, message: message, fields: headers, canonicalization: headerCanonicalizationAlgorithm, stream: filtered)

        builder.append("; h=")
        builder.appendJoin(separator: ":", values: headers)

        let bodyHash = try message.hashBody(signingOptions, signatureAlgorithm: signatureAlgorithm, bodyCanonicalization: bodyCanonicalizationAlgorithm, maxLength: -1)
        builder.append("; bh=")
        builder.append(Data(bodyHash).base64EncodedString())
        builder.append("; b=")

        let dkimHeader = Header(.dkimSignature, value: builder.toString())
        message.headers.insert(dkimHeader, at: 0)

        switch headerCanonicalizationAlgorithm {
        case .relaxed:
            try DkimVerifierBase.writeHeaderRelaxed(options: signingOptions, stream: filtered, header: dkimHeader, isDkimSignature: true)
        case .simple:
            try DkimVerifierBase.writeHeaderSimple(options: signingOptions, stream: filtered, header: dkimHeader, isDkimSignature: true)
        }

        try filtered.flush()

        let signature = try stream.generateSignature()
        dkimHeader.value += Data(signature).base64EncodedString()
    }

    private func canonicalizationToken(_ algorithm: DkimCanonicalizationAlgorithm) -> String {
        switch algorithm {
        case .relaxed:
            return "relaxed"
        case .simple:
            return "simple"
        }
    }

    private func getTimestamp() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }
}
