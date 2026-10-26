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
// DkimVerifierBase.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during DKIM verification operations.
public enum DkimVerifierError: Error, Equatable, Sendable {
    /// An invalid argument was provided to the verifier.
    case invalidArgument
    /// The DKIM header is malformed and cannot be parsed.
    case malformedHeader(String)
    /// The signature algorithm is not supported or not enabled.
    case unsupportedAlgorithm
    /// The public key is invalid or incompatible with the signature algorithm.
    case invalidKey
}

/// The base class for DKIM verifiers.
///
/// This class provides the common functionality for verifying DKIM signatures.
/// It handles signature algorithm configuration, public key lookup, and the
/// core verification logic.
///
/// ## Subclassing Notes
///
/// Subclasses like ``DkimVerifier`` extend this base class to provide the
/// public verification API for email messages.
///
/// ## Topics
///
/// ### Configuration
/// - ``minimumRsaKeyLength``
///
/// ### Algorithm Management
/// - ``enable(_:)``
/// - ``disable(_:)``
/// - ``isEnabled(_:)``
open class DkimVerifierBase {
    private static let colon: [UInt8] = [0x3A]
    private let publicKeyLocator: DkimPublicKeyLocator
    private var enabledSignatureAlgorithms: Int = 0

    /// The minimum allowed RSA key length in bits.
    ///
    /// Signatures using RSA keys shorter than this length will fail verification.
    /// The default value is 1024 bits, but higher values (e.g., 2048) are
    /// recommended for better security.
    public var minimumRsaKeyLength: Int = 1024

    /// Creates a new DKIM verifier base with the specified public key locator.
    ///
    /// By default, enables the ``DkimSignatureAlgorithm/ed25519Sha256`` and
    /// ``DkimSignatureAlgorithm/rsaSha256`` algorithms. The ``DkimSignatureAlgorithm/rsaSha1``
    /// algorithm is disabled by default due to security concerns.
    ///
    /// - Parameter publicKeyLocator: The service used to retrieve public keys via DNS.
    public init(publicKeyLocator: DkimPublicKeyLocator) {
        self.publicKeyLocator = publicKeyLocator
        enable(.ed25519Sha256)
        enable(.rsaSha256)
    }

    /// Enables the specified signature algorithm for verification.
    ///
    /// - Parameter algorithm: The signature algorithm to enable.
    ///
    /// By default, ``DkimSignatureAlgorithm/ed25519Sha256`` and
    /// ``DkimSignatureAlgorithm/rsaSha256`` are enabled.
    public func enable(_ algorithm: DkimSignatureAlgorithm) {
        enabledSignatureAlgorithms |= 1 << algorithm.bitIndex
    }

    /// Disables the specified signature algorithm for verification.
    ///
    /// Signatures using disabled algorithms will not be verified.
    ///
    /// - Parameter algorithm: The signature algorithm to disable.
    public func disable(_ algorithm: DkimSignatureAlgorithm) {
        enabledSignatureAlgorithms &= ~(1 << algorithm.bitIndex)
    }

    /// Returns whether the specified signature algorithm is enabled.
    ///
    /// - Parameter algorithm: The signature algorithm to check.
    /// - Returns: `true` if the algorithm is enabled for verification; otherwise, `false`.
    public func isEnabled(_ algorithm: DkimSignatureAlgorithm) -> Bool {
        (enabledSignatureAlgorithms & (1 << algorithm.bitIndex)) != 0
    }

    internal func locatePublicKey(methods: String, domain: String, selector: String) throws -> DkimPublicKey {
        try publicKeyLocator.locatePublicKey(methods: methods, domain: domain, selector: selector)
    }

    internal func locatePublicKeyAsync(methods: String, domain: String, selector: String) async throws -> DkimPublicKey {
        try await publicKeyLocator.locatePublicKeyAsync(methods: methods, domain: domain, selector: selector)
    }

    internal static func writeHeaderRelaxed(options: FormatOptions, stream: MimeStream, header: Header, isDkimSignature: Bool) throws {
        let name = Array(header.field.lowercased().utf8)
        let rawValue = header.getRawValue(options)
        var index = 0

        try stream.write(name, offset: 0, count: name.count)
        try stream.write(colon, offset: 0, count: colon.count)

        while index < rawValue.count && ByteClassification.isWhitespace(rawValue[index]) {
            index += 1
        }

        while index < rawValue.count {
            let startIndex = index
            while index < rawValue.count && ByteClassification.isWhitespace(rawValue[index]) {
                index += 1
            }

            if index >= rawValue.count {
                break
            }

            if index > startIndex {
                let space: [UInt8] = [0x20]
                try stream.write(space, offset: 0, count: space.count)
            }

            let wordStart = index
            while index < rawValue.count && !ByteClassification.isWhitespace(rawValue[index]) {
                index += 1
            }

            if index > wordStart {
                try stream.write(rawValue, offset: wordStart, count: index - wordStart)
            }
        }

        if !isDkimSignature {
            let newLine = options.newLineBytes
            try stream.write(newLine, offset: 0, count: newLine.count)
        }
    }

    internal static func writeHeaderSimple(options: FormatOptions, stream: MimeStream, header: Header, isDkimSignature: Bool) throws {
        let rawValue = header.getRawValue(options)
        var rawLength = rawValue.count

        if isDkimSignature && rawLength > 0 {
            if rawValue[rawLength - 1] == 0x0A {
                rawLength -= 1
                if rawLength > 0 && rawValue[rawLength - 1] == 0x0D {
                    rawLength -= 1
                }
            }
        }

        try stream.write(header.rawField, offset: 0, count: header.rawField.count)
        try stream.write(colon, offset: 0, count: colon.count)
        if rawLength > 0 {
            try stream.write(rawValue, offset: 0, count: rawLength)
        }
    }

    internal static func writeHeaders(options: FormatOptions, message: MimeMessage, fields: [String], canonicalization: DkimCanonicalizationAlgorithm, stream: MimeStream) throws {
        var counts: [String: Int] = [:]

        for field in fields {
            let headers: HeaderList
            if field.lowercased().hasPrefix("content-") {
                guard let body = message.body else {
                    continue
                }
                headers = body.headers
            } else {
                headers = message.headers
            }

            let name = field.lowercased()
            let count = counts[name] ?? 0

            var index = headers.count - 1
            var seen = 0
            var matchedIndex: Int? = nil

            while index >= 0 {
                if headers[index].field.caseInsensitiveCompare(name) == .orderedSame {
                    if seen == count {
                        matchedIndex = index
                        break
                    }
                    seen += 1
                }
                index -= 1
            }

            guard let headerIndex = matchedIndex else {
                continue
            }

            let header = headers[headerIndex]
            switch canonicalization {
            case .relaxed:
                try writeHeaderRelaxed(options: options, stream: stream, header: header, isDkimSignature: false)
            case .simple:
                try writeHeaderSimple(options: options, stream: stream, header: header, isDkimSignature: false)
            }

            counts[name] = count + 1
        }
    }

    internal static func parseParameterTags(headerId: HeaderId, signature: String) throws -> [String: String] {
        var parameters: [String: String] = [:]
        let chars = Array(signature)
        var index = 0

        func isWhitespace(_ c: Character) -> Bool {
            c == " " || c == "\t"
        }

        func isAlpha(_ c: Character) -> Bool {
            ("A"..."Z").contains(c) || ("a"..."z").contains(c)
        }

        while index < chars.count {
            while index < chars.count && isWhitespace(chars[index]) {
                index += 1
            }
            if index >= chars.count {
                break
            }

            if chars[index] == ";" || !isAlpha(chars[index]) {
                throw DkimVerifierError.malformedHeader("Malformed \(headerId.headerName) value.")
            }

            let startIndex = index
            index += 1
            while index < chars.count && chars[index] != "=" {
                index += 1
            }

            if index >= chars.count {
                continue
            }

            let name = String(chars[startIndex..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            index += 1

            var value = ""
            while index < chars.count && chars[index] != ";" {
                if !isWhitespace(chars[index]) {
                    value.append(chars[index])
                }
                index += 1
            }

            if parameters[name] != nil {
                throw DkimVerifierError.malformedHeader("Malformed \(headerId.headerName) value: duplicate parameter '\(name)'.")
            }

            parameters[name] = value

            if index < chars.count {
                index += 1
            }
        }

        return parameters
    }

    internal static func validateCommonParameters(header: String, parameters: [String: String]) throws -> (algorithm: DkimSignatureAlgorithm, d: String, s: String, q: String, b: String) {
        guard let a = parameters["a"] else {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: no signature algorithm parameter detected.")
        }

        let algorithm: DkimSignatureAlgorithm
        switch a.lowercased() {
        case "ed25519-sha256":
            algorithm = .ed25519Sha256
        case "rsa-sha256":
            algorithm = .rsaSha256
        case "rsa-sha1":
            algorithm = .rsaSha1
        default:
            throw DkimVerifierError.malformedHeader("Unrecognized \(header) algorithm parameter: a=\(a)")
        }

        guard let d = parameters["d"], !d.isEmpty else {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: no domain parameter detected.")
        }

        guard let s = parameters["s"], !s.isEmpty else {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: no selector parameter detected.")
        }

        let q = parameters["q"] ?? "dns/txt"

        guard let b = parameters["b"], !b.isEmpty else {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: no signature parameter detected.")
        }

        if let t = parameters["t"], let timestamp = Int(t), timestamp < 0 {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: invalid timestamp parameter: t=\(t).")
        }

        return (algorithm, d, s, q, b)
    }

    internal static func validateCommonSignatureParameters(header: String, parameters: [String: String]) throws -> (algorithm: DkimSignatureAlgorithm, headerAlgorithm: DkimCanonicalizationAlgorithm, bodyAlgorithm: DkimCanonicalizationAlgorithm, d: String, s: String, q: String, headers: [String], bh: String, b: String, maxLength: Int) {
        let common = try validateCommonParameters(header: header, parameters: parameters)

        let maxLength: Int
        if let l = parameters["l"], let value = Int(l), value >= 0 {
            maxLength = value
        } else if parameters["l"] != nil {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: invalid length parameter.")
        } else {
            maxLength = -1
        }

        let headerAlgorithm: DkimCanonicalizationAlgorithm
        let bodyAlgorithm: DkimCanonicalizationAlgorithm

        if let c = parameters["c"] {
            let tokens = c.lowercased().split(separator: "/")
            guard tokens.count >= 1 && tokens.count <= 2 else {
                throw DkimVerifierError.malformedHeader("Malformed \(header) header: invalid canonicalization parameter: c=\(c)")
            }

            switch tokens[0] {
            case "relaxed":
                headerAlgorithm = .relaxed
            case "simple":
                headerAlgorithm = .simple
            default:
                throw DkimVerifierError.malformedHeader("Malformed \(header) header: invalid canonicalization parameter: c=\(c)")
            }

            if tokens.count == 2 {
                switch tokens[1] {
                case "relaxed":
                    bodyAlgorithm = .relaxed
                case "simple":
                    bodyAlgorithm = .simple
                default:
                    throw DkimVerifierError.malformedHeader("Malformed \(header) header: invalid canonicalization parameter: c=\(c)")
                }
            } else {
                bodyAlgorithm = .simple
            }
        } else {
            headerAlgorithm = .simple
            bodyAlgorithm = .simple
        }

        guard let h = parameters["h"] else {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: no signed header parameter detected.")
        }

        let headers = h.split(separator: ":").map { String($0) }

        guard let bh = parameters["bh"] else {
            throw DkimVerifierError.malformedHeader("Malformed \(header) header: no body hash parameter detected.")
        }

        return (common.algorithm, headerAlgorithm, bodyAlgorithm, common.d, common.s, common.q, headers, bh, common.b, maxLength)
    }

    internal static func getSignedSignatureHeader(_ header: Header) throws -> Header {
        var rawValue = header.rawValue
        var length = 0
        var index = 0

        while index < rawValue.count {
            while index < rawValue.count && ByteClassification.isWhitespace(rawValue[index]) {
                index += 1
            }

            if index + 2 < rawValue.count {
                let param = rawValue[index]
                index += 1

                while index < rawValue.count && ByteClassification.isWhitespace(rawValue[index]) {
                    index += 1
                }

                if index < rawValue.count && rawValue[index] == UInt8(ascii: "=") && param == UInt8(ascii: "b") {
                    length = index + 1
                    index += 1

                    while index < rawValue.count && rawValue[index] != UInt8(ascii: ";") {
                        index += 1
                    }

                    if index == rawValue.count && rawValue[index - 1] == UInt8(ascii: "\n") {
                        index -= 1
                        if index > 0 && rawValue[index - 1] == UInt8(ascii: "\r") {
                            index -= 1
                        }
                    }
                    break
                }
            }

            while index < rawValue.count && rawValue[index] != UInt8(ascii: ";") {
                index += 1
            }

            if index < rawValue.count {
                index += 1
            }
        }

        if index == rawValue.count {
            throw DkimVerifierError.malformedHeader("Malformed \(header.field) header: missing signature parameter.")
        }

        while index < rawValue.count {
            rawValue[length] = rawValue[index]
            length += 1
            index += 1
        }

        rawValue.removeLast(rawValue.count - length)

        return Header(header.options, header.id, header.field, rawValue)
    }

    internal static func verifyBodyHash(options: FormatOptions, message: MimeMessage, signatureAlgorithm: DkimSignatureAlgorithm, canonicalizationAlgorithm: DkimCanonicalizationAlgorithm, maxLength: Int, bodyHash: String) throws -> Bool {
        let hash = try message.hashBody(options, signatureAlgorithm: signatureAlgorithm, bodyCanonicalization: canonicalizationAlgorithm, maxLength: maxLength)
        let computed = Data(hash).base64EncodedString()
        return computed == bodyHash
    }

    internal func verifySignature(options: FormatOptions, message: MimeMessage, dkimSignature: Header, signatureAlgorithm: DkimSignatureAlgorithm, key: DkimPublicKey, headers: [String], canonicalizationAlgorithm: DkimCanonicalizationAlgorithm, signature: String) throws -> Bool {
        let context = try createVerifyContext(signatureAlgorithm, key: key)
        let stream = try DkimSignatureStream(context)
        let filtered = try FilteredStream(stream)
        try filtered.add(options.createNewLineFilter(false))

        try DkimVerifierBase.writeHeaders(options: options, message: message, fields: headers, canonicalization: canonicalizationAlgorithm, stream: filtered)

        let signedHeader = try DkimVerifierBase.getSignedSignatureHeader(dkimSignature)
        switch canonicalizationAlgorithm {
        case .relaxed:
            try DkimVerifierBase.writeHeaderRelaxed(options: options, stream: filtered, header: signedHeader, isDkimSignature: true)
        case .simple:
            try DkimVerifierBase.writeHeaderSimple(options: options, stream: filtered, header: signedHeader, isDkimSignature: true)
        }

        try filtered.flush()
        return try stream.verifySignature(signature)
    }

    internal func createVerifyContext(_ algorithm: DkimSignatureAlgorithm, key: DkimPublicKey) throws -> DkimSignatureContext {
        switch algorithm {
        case .rsaSha1, .rsaSha256:
            guard case .rsa(let publicKey) = key else {
                throw DkimVerifierError.invalidKey
            }
            return DkimRsaVerifyContext(key: publicKey, algorithm: algorithm)
        case .ed25519Sha256:
            guard case .ed25519(let publicKey) = key else {
                throw DkimVerifierError.invalidKey
            }
            return DkimEd25519VerifyContext(key: publicKey)
        }
    }
}

private extension DkimSignatureAlgorithm {
    var bitIndex: Int {
        switch self {
        case .rsaSha1:
            return 0
        case .rsaSha256:
            return 1
        case .ed25519Sha256:
            return 2
        }
    }
}
