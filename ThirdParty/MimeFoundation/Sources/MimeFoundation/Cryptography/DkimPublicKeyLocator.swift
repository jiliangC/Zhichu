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
// DkimPublicKeyLocator.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation
import Crypto
import _CryptoExtras

/// Errors that can occur during DKIM public key location operations.
public enum DkimPublicKeyLocatorError: Error, Equatable, Sendable {
    /// An invalid argument was provided to the public key locator.
    case invalidArgument
}

/// A protocol for services that locate and retrieve DKIM public keys.
///
/// Since MimeFoundation itself does not implement DNS lookup, it is up to the
/// client application to implement public key lookups via DNS.
///
/// Implementations of this protocol are used by ``DkimVerifier`` to retrieve
/// the public key needed to verify DKIM signatures.
///
/// ## Implementation Notes
///
/// Typically, implementations will query DNS TXT records at
/// `{selector}._domainkey.{domain}` to retrieve the DKIM public key record.
///
/// ## Topics
///
/// ### Locating Public Keys
/// - ``locatePublicKey(methods:domain:selector:)``
/// - ``locatePublicKeyAsync(methods:domain:selector:)``
///
/// ### Related Types
/// - ``DkimPublicKeyLocatorBase``
/// - ``DkimPublicKey``
/// - ``DkimVerifier``
public protocol DkimPublicKeyLocator: AnyObject {
    /// Locates and retrieves the public key for the given domain and selector.
    ///
    /// - Parameters:
    ///   - methods: A colon-separated list of query methods used to retrieve
    ///     the public key. The default is `"dns/txt"`.
    ///   - domain: The domain that signed the message.
    ///   - selector: The selector subdividing the domain's namespace.
    /// - Returns: The ``DkimPublicKey`` for verifying signatures.
    /// - Throws: An error if the public key cannot be located or parsed.
    func locatePublicKey(methods: String, domain: String, selector: String) throws -> DkimPublicKey

    /// Asynchronously locates and retrieves the public key for the given domain and selector.
    ///
    /// - Parameters:
    ///   - methods: A colon-separated list of query methods used to retrieve
    ///     the public key. The default is `"dns/txt"`.
    ///   - domain: The domain that signed the message.
    ///   - selector: The selector subdividing the domain's namespace.
    /// - Returns: The ``DkimPublicKey`` for verifying signatures.
    /// - Throws: An error if the public key cannot be located or parsed.
    func locatePublicKeyAsync(methods: String, domain: String, selector: String) async throws -> DkimPublicKey
}

/// A base class for implementing DKIM public key locators.
///
/// This class provides a foundation for implementing the ``DkimPublicKeyLocator``
/// protocol. Subclasses should override ``locatePublicKey(methods:domain:selector:)``
/// to provide the actual DNS lookup implementation.
///
/// ## Subclassing Notes
///
/// When implementing a subclass:
/// 1. Override ``locatePublicKey(methods:domain:selector:)`` with your DNS lookup logic
/// 2. Optionally override ``locatePublicKeyAsync(methods:domain:selector:)`` for
///    optimized async implementations
/// 3. Use ``getPublicKey(_:)`` to parse the DNS TXT record value
///
/// ## Example
///
/// ```swift
/// class MyDkimPublicKeyLocator: DkimPublicKeyLocatorBase {
///     override func locatePublicKey(methods: String, domain: String, selector: String) throws -> DkimPublicKey {
///         let txtRecord = performDnsLookup("\(selector)._domainkey.\(domain)")
///         return try DkimPublicKeyLocatorBase.getPublicKey(txtRecord)
///     }
/// }
/// ```
open class DkimPublicKeyLocatorBase: DkimPublicKeyLocator {
    /// Creates a new instance of the DKIM public key locator base.
    public init() {}

    /// Locates and retrieves the public key for the given domain and selector.
    ///
    /// The default implementation throws a fatal error. Subclasses must override
    /// this method to provide the actual DNS lookup implementation.
    ///
    /// - Parameters:
    ///   - methods: A colon-separated list of query methods.
    ///   - domain: The domain that signed the message.
    ///   - selector: The selector subdividing the domain's namespace.
    /// - Returns: The public key for verifying signatures.
    /// - Throws: An error if the public key cannot be located.
    open func locatePublicKey(methods: String, domain: String, selector: String) throws -> DkimPublicKey {
        fatalError("Subclasses must override locatePublicKey")
    }

    /// Asynchronously locates and retrieves the public key for the given domain and selector.
    ///
    /// The default implementation calls the synchronous ``locatePublicKey(methods:domain:selector:)``
    /// method. Subclasses may override this to provide an optimized async implementation.
    ///
    /// - Parameters:
    ///   - methods: A colon-separated list of query methods.
    ///   - domain: The domain that signed the message.
    ///   - selector: The selector subdividing the domain's namespace.
    /// - Returns: The public key for verifying signatures.
    /// - Throws: An error if the public key cannot be located.
    open func locatePublicKeyAsync(methods: String, domain: String, selector: String) async throws -> DkimPublicKey {
        try locatePublicKey(methods: methods, domain: domain, selector: selector)
    }

    /// Parses a DKIM public key from a DNS TXT record value.
    ///
    /// This method parses the DKIM key record format as specified in RFC 6376.
    /// The record should contain key-value pairs separated by semicolons, including:
    /// - `k`: The key type (`rsa` or `ed25519`)
    /// - `p`: The Base64-encoded public key
    ///
    /// - Parameter txt: The DNS TXT record value containing the DKIM public key.
    /// - Returns: The parsed ``DkimPublicKey``.
    /// - Throws: ``ParseException`` if the record is malformed or missing required fields.
    static func getPublicKey(_ txt: String?) throws -> DkimPublicKey {
        guard let txt else {
            throw DkimPublicKeyLocatorError.invalidArgument
        }

        var algorithm = "rsa"
        var publicKeyBase64: String?
        var index = 0
        let length = txt.utf16.count

        while index < length {
            while index < length {
                let codeUnit = txt.utf16CodeUnit(at: index)
                if codeUnit != 0x20 && codeUnit != 0x09 && codeUnit != 0x0A && codeUnit != 0x0D {
                    break
                }
                index += 1
            }

            if index >= length {
                break
            }

            let keyStart = index
            while index < length, txt.utf16CodeUnit(at: index) != 0x3D {
                index += 1
            }
            if index >= length {
                break
            }

            let key = txt.sliceUtf16(keyStart, index)
            index += 1

            let valueStart = index
            while index < length, txt.utf16CodeUnit(at: index) != 0x3B {
                index += 1
            }

            let value = txt.sliceUtf16(valueStart, index)

            if key == "k" {
                switch value {
                case "rsa", "ed25519":
                    algorithm = value
                default:
                    throw ParseException("Unknown public key algorithm: \(value)", tokenIndex: valueStart, errorIndex: index)
                }
            } else if key == "p" {
                publicKeyBase64 = value.replacingOccurrences(of: " ", with: "")
            }

            index += 1
        }

        guard let publicKeyBase64, !publicKeyBase64.isEmpty else {
            throw ParseException("Public key parameters not found in DNS TXT record.", tokenIndex: 0, errorIndex: length)
        }

        guard let decoded = Data(base64Encoded: publicKeyBase64, options: [.ignoreUnknownCharacters]) else {
            throw ParseException("Public key parameters not found in DNS TXT record.", tokenIndex: 0, errorIndex: length)
        }

        if algorithm == "ed25519" {
            do {
                let key = try Curve25519.Signing.PublicKey(rawRepresentation: decoded)
                return .ed25519(key)
            } catch {
                throw ParseException("Public key parameters not found in DNS TXT record.", tokenIndex: 0, errorIndex: length)
            }
        }

        do {
            let key = try _RSA.Signing.PublicKey(unsafeDERRepresentation: decoded)
            return .rsa(key)
        } catch {
            throw ParseException("Public key parameters not found in DNS TXT record.", tokenIndex: 0, errorIndex: length)
        }
    }
}

private extension String {
    func sliceUtf16(_ start: Int, _ end: Int) -> String {
        guard start < end else { return "" }
        let startIndex = String.Index(utf16Offset: start, in: self)
        let endIndex = String.Index(utf16Offset: end, in: self)
        return String(self[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func utf16CodeUnit(at index: Int) -> UInt16 {
        let utf16Index = utf16.index(utf16.startIndex, offsetBy: index)
        return utf16[utf16Index]
    }
}
