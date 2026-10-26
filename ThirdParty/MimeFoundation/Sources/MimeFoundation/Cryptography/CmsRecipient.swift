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
// CmsRecipient.swift
//
// Represents a recipient for CMS encryption operations.
//

import Foundation
#if canImport(Security)
import Security
#endif
@_spi(CMS) import X509

/// An S/MIME recipient for CMS encryption operations.
///
/// A recipient is identified by their X.509 certificate, which contains the
/// public key used to encrypt the message encryption key. When encrypting
/// a message for multiple recipients, each recipient's certificate is used
/// to create an encrypted copy of the symmetric encryption key.
///
/// ## Usage
///
/// ```swift
/// // Create a recipient from a certificate
/// let recipient = try CmsRecipient(pemEncoded: certificatePEM)
///
/// // Create a collection and encrypt
/// var recipients = CmsRecipientCollection()
/// recipients.add(recipient)
///
/// let context = SecureMimeContext()
/// let encrypted = try context.encrypt(recipients: recipients, entity: entity)
/// ```
///
/// ## Topics
///
/// ### Creating a Recipient
/// - ``init(certificate:)``
/// - ``init(pemEncoded:)``
/// - ``init(derEncoded:)``
/// - ``init(secCertificate:)``
///
/// ### Properties
/// - ``certificate``
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct CmsRecipient: Sendable {
    /// The recipient's X.509 certificate.
    ///
    /// This certificate contains the public key that will be used to encrypt
    /// the message encryption key for this recipient.
    public let certificate: Certificate

    /// Creates a new CMS recipient with the specified certificate.
    ///
    /// - Parameter certificate: The recipient's X.509 certificate.
    public init(certificate: Certificate) {
        self.certificate = certificate
    }

    /// Creates a CMS recipient from a PEM-encoded certificate.
    ///
    /// - Parameter pemEncoded: The PEM-encoded certificate string.
    /// - Throws: ``SecureMimeError/invalidCertificate(_:)`` if the certificate
    ///   cannot be parsed.
    public init(pemEncoded: String) throws {
        do {
            self.certificate = try Certificate(pemEncoded: pemEncoded)
        } catch {
            throw SecureMimeError.invalidCertificate(String(describing: error))
        }
    }

    /// Creates a CMS recipient from DER-encoded certificate data.
    ///
    /// - Parameter derEncoded: The DER-encoded certificate bytes.
    /// - Throws: ``SecureMimeError/invalidCertificate(_:)`` if the certificate
    ///   cannot be parsed.
    public init(derEncoded: [UInt8]) throws {
        do {
            self.certificate = try Certificate(derEncoded: derEncoded)
        } catch {
            throw SecureMimeError.invalidCertificate(String(describing: error))
        }
    }

    #if canImport(Security)
    /// Creates a CMS recipient from a Security framework certificate.
    ///
    /// This initializer is only available on Apple platforms.
    ///
    /// - Parameter secCertificate: The `SecCertificate` to convert.
    /// - Throws: ``SecureMimeError/invalidCertificate(_:)`` if the certificate
    ///   cannot be converted.
    public init(secCertificate: SecCertificate) throws {
        do {
            self.certificate = try Certificate(secCertificate)
        } catch {
            throw SecureMimeError.invalidCertificate(String(describing: error))
        }
    }

    /// Converts this recipient's certificate to a Security framework certificate.
    ///
    /// This method is only available on Apple platforms.
    ///
    /// - Returns: The `SecCertificate` representation.
    /// - Throws: ``SecureMimeError/invalidCertificate(_:)`` if conversion fails.
    public func toSecCertificate() throws -> SecCertificate {
        do {
            return try SecCertificate.makeWithCertificate(certificate)
        } catch {
            throw SecureMimeError.invalidCertificate(String(describing: error))
        }
    }
    #endif
}

/// A collection of S/MIME recipients for encryption operations.
///
/// This collection is used to specify multiple recipients when encrypting
/// a message. Each recipient in the collection will receive their own
/// encrypted copy of the symmetric encryption key.
///
/// ## Topics
///
/// ### Creating a Collection
/// - ``init()``
/// - ``init(_:)``
/// - ``init(arrayLiteral:)``
///
/// ### Adding Recipients
/// - ``add(_:)``
/// - ``add(certificate:)``
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct CmsRecipientCollection: Sendable, RandomAccessCollection, ExpressibleByArrayLiteral {
    public typealias Element = CmsRecipient
    public typealias Index = Int

    private var recipients: [CmsRecipient]

    /// Creates an empty recipient collection.
    public init() {
        self.recipients = []
    }

    /// Creates a recipient collection from an array of recipients.
    ///
    /// - Parameter recipients: The recipients to include.
    public init(_ recipients: [CmsRecipient]) {
        self.recipients = recipients
    }

    /// Creates a recipient collection from an array literal.
    public init(arrayLiteral elements: CmsRecipient...) {
        self.recipients = elements
    }

    /// The start index of the collection.
    public var startIndex: Int { recipients.startIndex }

    /// The end index of the collection.
    public var endIndex: Int { recipients.endIndex }

    /// Returns the index after the given index.
    public func index(after i: Int) -> Int { recipients.index(after: i) }

    /// Accesses the recipient at the specified index.
    public subscript(position: Int) -> CmsRecipient {
        recipients[position]
    }

    /// The number of recipients in the collection.
    public var count: Int { recipients.count }

    /// Adds a recipient to the collection.
    ///
    /// - Parameter recipient: The recipient to add.
    public mutating func add(_ recipient: CmsRecipient) {
        recipients.append(recipient)
    }

    /// Adds a recipient with the specified certificate.
    ///
    /// - Parameter certificate: The recipient's certificate.
    public mutating func add(certificate: Certificate) {
        recipients.append(CmsRecipient(certificate: certificate))
    }
}
