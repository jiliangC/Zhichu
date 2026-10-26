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
// SecureMailboxAddress.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when creating a ``SecureMailboxAddress``.
public enum SecureMailboxAddressError: Error, Sendable {
    /// The fingerprint is invalid (must be a hex-encoded string).
    case invalidFingerprint
}

/// A secure mailbox address which includes a fingerprint for a certificate.
///
/// When signing or encrypting a message, it is necessary to look up the X.509
/// certificate in order to perform the actual sign or encrypt operation. One way
/// of accomplishing this is to use the email address of the sender or recipient
/// as a unique identifier. However, a better approach is to use the fingerprint
/// (or 'thumbprint' in Microsoft parlance) of the user's certificate.
///
/// ## Usage
///
/// ```swift
/// // Create a secure mailbox address with a certificate fingerprint
/// let secureAddress = try SecureMailboxAddress(
///     name: "John Doe",
///     address: "john@example.com",
///     fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
/// )
/// ```
///
/// ## Topics
///
/// ### Creating a Secure Address
/// - ``init(encoding:name:route:address:fingerprint:)``
/// - ``init(name:route:address:fingerprint:)``
/// - ``init(encoding:name:address:fingerprint:)``
/// - ``init(name:address:fingerprint:)``
///
/// ### Properties
/// - ``fingerprint``
public final class SecureMailboxAddress: MailboxAddress {
    /// The fingerprint of the certificate and/or key to use for signing or encrypting.
    ///
    /// A fingerprint is a SHA-1 hash of the raw certificate data and is often used
    /// as a unique identifier for a particular certificate in a certificate store.
    /// The fingerprint must be a hex-encoded string.
    public let fingerprint: String

    /// Creates a new secure mailbox address with the specified fingerprint.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the mailbox, or `nil` if not specified.
    ///   - route: The route of the mailbox.
    ///   - address: The address of the mailbox.
    ///   - fingerprint: The fingerprint of the certificate belonging to the owner
    ///     of the mailbox. Must be a hex-encoded string.
    /// - Throws: ``SecureMailboxAddressError/invalidFingerprint`` if the fingerprint
    ///   is not a valid hex-encoded string.
    public init(encoding: String.Encoding, name: String?, route: [String], address: String, fingerprint: String) throws {
        try SecureMailboxAddress.validateFingerprint(fingerprint)
        self.fingerprint = fingerprint
        super.init(encoding: encoding, name: name, route: route, address: address)
    }

    /// Internal initializer for cloning. Assumes fingerprint is already validated.
    private init(cloning encoding: String.Encoding, name: String?, route: [String], address: String, fingerprint: String) {
        self.fingerprint = fingerprint
        super.init(encoding: encoding, name: name, route: route, address: address)
    }

    /// Creates a new secure mailbox address with the specified fingerprint.
    ///
    /// The name will be encoded using UTF-8.
    ///
    /// - Parameters:
    ///   - name: The name of the mailbox, or `nil` if not specified.
    ///   - route: The route of the mailbox.
    ///   - address: The address of the mailbox.
    ///   - fingerprint: The fingerprint of the certificate belonging to the owner
    ///     of the mailbox. Must be a hex-encoded string.
    /// - Throws: ``SecureMailboxAddressError/invalidFingerprint`` if the fingerprint
    ///   is not a valid hex-encoded string.
    public convenience init(name: String?, route: [String], address: String, fingerprint: String) throws {
        try self.init(encoding: .utf8, name: name, route: route, address: address, fingerprint: fingerprint)
    }

    /// Creates a new secure mailbox address with the specified fingerprint.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to be used for encoding the name.
    ///   - name: The name of the mailbox, or `nil` if not specified.
    ///   - address: The address of the mailbox.
    ///   - fingerprint: The fingerprint of the certificate belonging to the owner
    ///     of the mailbox. Must be a hex-encoded string.
    /// - Throws: ``SecureMailboxAddressError/invalidFingerprint`` if the fingerprint
    ///   is not a valid hex-encoded string.
    public init(encoding: String.Encoding, name: String?, address: String, fingerprint: String) throws {
        try SecureMailboxAddress.validateFingerprint(fingerprint)
        self.fingerprint = fingerprint
        super.init(encoding: encoding, name: name, address: address)
    }

    /// Creates a new secure mailbox address with the specified fingerprint.
    ///
    /// The name will be encoded using UTF-8.
    ///
    /// - Parameters:
    ///   - name: The name of the mailbox, or `nil` if not specified.
    ///   - address: The address of the mailbox.
    ///   - fingerprint: The fingerprint of the certificate belonging to the owner
    ///     of the mailbox. Must be a hex-encoded string.
    /// - Throws: ``SecureMailboxAddressError/invalidFingerprint`` if the fingerprint
    ///   is not a valid hex-encoded string.
    public convenience init(name: String?, address: String, fingerprint: String) throws {
        try self.init(encoding: .utf8, name: name, address: address, fingerprint: fingerprint)
    }

    /// Creates a copy of this secure mailbox address.
    ///
    /// - Returns: A new ``SecureMailboxAddress`` with the same properties.
    public override func copy() -> InternetAddress {
        let routes = Array(route)
        return SecureMailboxAddress(cloning: encoding, name: name, route: routes, address: address, fingerprint: fingerprint)
    }

    /// Validates that the fingerprint is a valid hex-encoded string.
    private static func validateFingerprint(_ fingerprint: String) throws {
        for byte in fingerprint.utf8 {
            if byte > 0x7F || !ByteClassification.isXDigit(byte) {
                throw SecureMailboxAddressError.invalidFingerprint
            }
        }
    }
}
