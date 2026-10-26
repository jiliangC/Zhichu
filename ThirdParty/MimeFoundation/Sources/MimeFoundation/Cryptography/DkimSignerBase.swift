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
// DkimSignerBase.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation
import Crypto
import _CryptoExtras

/// Errors that can occur during DKIM signing operations.
public enum DkimSignerError: Error, Equatable, Sendable {
    /// An invalid argument was provided.
    case invalidArgument
    /// The private key is invalid or incompatible with the signature algorithm.
    case invalidPrivateKey
    /// The specified signature algorithm is not supported.
    case unsupportedAlgorithm
    /// Failed to read the private key file.
    case fileReadFailed
}

/// A DKIM private key for signing operations.
///
/// This enum wraps the cryptographic private keys used for DKIM signing,
/// supporting both RSA and Ed25519 key types.
public enum DkimPrivateKey: Sendable {
    /// An RSA private key for RSA-SHA1 or RSA-SHA256 signing.
    case rsa(_RSA.Signing.PrivateKey)
    /// An Ed25519 private key for Ed25519-SHA256 signing.
    case ed25519(Curve25519.Signing.PrivateKey)
}

/// The base class for DKIM signers.
///
/// This class provides the common functionality for creating DKIM signatures.
/// It handles key management, canonicalization algorithm configuration, and
/// signature expiration settings.
///
/// ## Subclassing Notes
///
/// Subclasses like ``DkimSigner`` extend this base class to provide the
/// actual signing functionality for email messages.
///
/// ## Topics
///
/// ### Configuration Properties
/// - ``domain``
/// - ``selector``
/// - ``signatureAlgorithm``
/// - ``bodyCanonicalizationAlgorithm``
/// - ``headerCanonicalizationAlgorithm``
/// - ``signaturesExpireAfter``
///
/// ### Creating a Signer
/// - ``init(privateKey:domain:selector:algorithm:)``
/// - ``init(filePath:domain:selector:algorithm:)``
/// - ``init(privateKeyData:domain:selector:algorithm:)``
/// - ``init(stream:domain:selector:algorithm:)``
open class DkimSignerBase {
    /// The domain that the signer represents.
    ///
    /// This is the `d=` tag in the DKIM signature, identifying the signing domain.
    public let domain: String

    /// The selector subdividing the domain's namespace.
    ///
    /// This is the `s=` tag in the DKIM signature. The selector is used together
    /// with the domain to form the DNS query for the public key:
    /// `{selector}._domainkey.{domain}`.
    public let selector: String

    /// The signature algorithm to use.
    ///
    /// Specifies which cryptographic algorithm to use for generating the
    /// DKIM signature. The default is ``DkimSignatureAlgorithm/rsaSha256``.
    ///
    /// - Warning: Due to the recognized weakness of the SHA-1 hash algorithm,
    ///   it is recommended that ``DkimSignatureAlgorithm/rsaSha1`` NOT be used.
    public var signatureAlgorithm: DkimSignatureAlgorithm

    /// The canonicalization algorithm to use for the message body.
    ///
    /// This is the body part of the `c=` tag in the DKIM signature.
    /// The default is ``DkimCanonicalizationAlgorithm/simple``.
    public var bodyCanonicalizationAlgorithm: DkimCanonicalizationAlgorithm

    /// The canonicalization algorithm to use for the message headers.
    ///
    /// This is the header part of the `c=` tag in the DKIM signature.
    /// The default is ``DkimCanonicalizationAlgorithm/simple``.
    public var headerCanonicalizationAlgorithm: DkimCanonicalizationAlgorithm

    /// The duration after which signatures expire, or `nil` for no expiration.
    ///
    /// If set, the `x=` tag will be included in the DKIM signature, specifying
    /// when the signature should no longer be considered valid.
    public var signaturesExpireAfter: TimeInterval?

    internal let privateKey: DkimPrivateKey

    /// Creates a new DKIM signer base with the specified private key.
    ///
    /// - Parameters:
    ///   - privateKey: The private key to use for signing.
    ///   - domain: The domain that the signer represents.
    ///   - selector: The selector subdividing the domain.
    ///   - algorithm: The signature algorithm. Defaults to ``DkimSignatureAlgorithm/rsaSha256``.
    /// - Throws: ``DkimSignerError/invalidArgument`` if the domain or selector is empty.
    public init(privateKey: DkimPrivateKey, domain: String, selector: String, algorithm: DkimSignatureAlgorithm = .rsaSha256) throws {
        guard !domain.isEmpty, !selector.isEmpty else {
            throw DkimSignerError.invalidArgument
        }

        self.privateKey = privateKey
        self.domain = domain
        self.selector = selector
        self.signatureAlgorithm = algorithm
        self.bodyCanonicalizationAlgorithm = .simple
        self.headerCanonicalizationAlgorithm = .simple
        self.signaturesExpireAfter = nil
    }

    /// Creates a new DKIM signer base by loading a private key from a file.
    ///
    /// The private key file should be in PEM format for RSA keys, or raw
    /// binary format for Ed25519 keys.
    ///
    /// - Parameters:
    ///   - filePath: The path to the private key file.
    ///   - domain: The domain that the signer represents.
    ///   - selector: The selector subdividing the domain.
    ///   - algorithm: The signature algorithm. Defaults to RSA-SHA256.
    /// - Throws: ``DkimSignerError/fileReadFailed`` if the file cannot be read,
    ///   or ``DkimSignerError/invalidPrivateKey`` if the key cannot be parsed.
    public convenience init(filePath: String, domain: String, selector: String, algorithm: DkimSignatureAlgorithm = .rsaSha256) throws {
        guard !filePath.isEmpty else {
            throw DkimSignerError.invalidArgument
        }
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        } catch {
            throw DkimSignerError.fileReadFailed
        }
        try self.init(privateKeyData: data, domain: domain, selector: selector, algorithm: algorithm)
    }

    /// Creates a new DKIM signer base from private key data.
    ///
    /// The data should be PEM-encoded for RSA keys, or raw binary for Ed25519 keys.
    ///
    /// - Parameters:
    ///   - privateKeyData: The private key data.
    ///   - domain: The domain that the signer represents.
    ///   - selector: The selector subdividing the domain.
    ///   - algorithm: The signature algorithm. Defaults to RSA-SHA256.
    /// - Throws: ``DkimSignerError/invalidPrivateKey`` if the key cannot be parsed.
    public convenience init(privateKeyData: Data, domain: String, selector: String, algorithm: DkimSignatureAlgorithm = .rsaSha256) throws {
        let key = try Self.loadPrivateKey(from: privateKeyData)
        try self.init(privateKey: key, domain: domain, selector: selector, algorithm: algorithm)
    }

    /// Creates a new DKIM signer base by reading a private key from a stream.
    ///
    /// - Parameters:
    ///   - stream: The stream containing the private key data.
    ///   - domain: The domain that the signer represents.
    ///   - selector: The selector subdividing the domain.
    ///   - algorithm: The signature algorithm. Defaults to RSA-SHA256.
    /// - Throws: ``DkimSignerError/invalidPrivateKey`` if the key cannot be parsed.
    public convenience init(stream: MimeStream, domain: String, selector: String, algorithm: DkimSignatureAlgorithm = .rsaSha256) throws {
        let bytes = try Self.readAllBytes(from: stream)
        try self.init(privateKeyData: Data(bytes), domain: domain, selector: selector, algorithm: algorithm)
    }

    internal func createSigningContext() throws -> DkimSignatureContext {
        switch signatureAlgorithm {
        case .rsaSha1:
            guard case .rsa(let key) = privateKey else {
                throw DkimSignerError.invalidPrivateKey
            }
            return DkimRsaSignatureContext(key: key, algorithm: .rsaSha1)
        case .rsaSha256:
            guard case .rsa(let key) = privateKey else {
                throw DkimSignerError.invalidPrivateKey
            }
            return DkimRsaSignatureContext(key: key, algorithm: .rsaSha256)
        case .ed25519Sha256:
            guard case .ed25519(let key) = privateKey else {
                throw DkimSignerError.invalidPrivateKey
            }
            return DkimEd25519SignatureContext(key: key)
        }
    }

    private static func loadPrivateKey(from data: Data) throws -> DkimPrivateKey {
        if let pem = String(data: data, encoding: .utf8) {
            if let key = try? _RSA.Signing.PrivateKey(unsafePEMRepresentation: pem) {
                return .rsa(key)
            }
        }
        if data.count == 32 || data.count == 64 {
            if let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
                return .ed25519(key)
            }
        }
        throw DkimSignerError.invalidPrivateKey
    }

    private static func readAllBytes(from stream: MimeStream) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data: [UInt8] = []
        _ = try? stream.seek(0, origin: .begin)
        while true {
            let read = try stream.read(&buffer, offset: 0, count: buffer.count)
            if read == 0 {
                break
            }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }
}
