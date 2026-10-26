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
// X509CertificateChain.swift
//
// Ordered certificate chain from subject to root.
//

import Foundation
@_spi(CMS) import X509

/// An ordered chain of X.509 certificates from subject to root.
///
/// A certificate chain represents the path from an end-entity certificate
/// (at index 0) through intermediate certificates to a root CA certificate
/// (at the last index).
///
/// ## Usage
///
/// ```swift
/// var chain = X509CertificateChain()
/// chain.add(endEntityCert)
/// chain.add(intermediateCert)
/// chain.add(rootCert)
///
/// // Access certificates
/// let leaf = chain[0]
/// let root = chain.last
/// ```
///
/// ## Collection Conformance
///
/// `X509CertificateChain` conforms to `RandomAccessCollection`, allowing
/// standard collection operations like iteration, mapping, and subscript access.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct X509CertificateChain: Sendable {
    private var certificates: [Certificate]

    /// Creates an empty certificate chain.
    public init() {
        self.certificates = []
    }

    /// Creates a certificate chain with the given certificates.
    ///
    /// - Parameter certificates: The certificates, ordered from subject to root.
    public init(_ certificates: [Certificate]) {
        self.certificates = certificates
    }

    /// Creates a certificate chain with a single certificate.
    ///
    /// - Parameter certificate: The initial certificate (typically the leaf).
    public init(_ certificate: Certificate) {
        self.certificates = [certificate]
    }

    /// The number of certificates in the chain.
    public var count: Int {
        return certificates.count
    }

    /// A Boolean value indicating whether the chain is empty.
    public var isEmpty: Bool {
        return certificates.isEmpty
    }

    /// The leaf certificate (end-entity), if the chain is not empty.
    public var leaf: Certificate? {
        return certificates.first
    }

    /// The root certificate, if the chain is not empty.
    public var root: Certificate? {
        return certificates.last
    }

    /// The first certificate in the chain.
    public var first: Certificate? {
        return certificates.first
    }

    /// The last certificate in the chain.
    public var last: Certificate? {
        return certificates.last
    }

    // MARK: - Modifying the Chain

    /// Appends a certificate to the end of the chain.
    ///
    /// Typically, certificates are added in order from subject to root,
    /// so this would add the next issuer in the chain.
    ///
    /// - Parameter certificate: The certificate to add.
    public mutating func add(_ certificate: Certificate) {
        certificates.append(certificate)
    }

    /// Appends multiple certificates to the end of the chain.
    ///
    /// - Parameter newCertificates: The certificates to add.
    public mutating func add(_ newCertificates: [Certificate]) {
        certificates.append(contentsOf: newCertificates)
    }

    /// Inserts a certificate at the specified position.
    ///
    /// - Parameters:
    ///   - certificate: The certificate to insert.
    ///   - index: The position at which to insert the certificate.
    public mutating func insert(_ certificate: Certificate, at index: Int) {
        certificates.insert(certificate, at: index)
    }

    /// Removes a certificate from the chain.
    ///
    /// - Parameter certificate: The certificate to remove.
    /// - Returns: `true` if the certificate was found and removed.
    @discardableResult
    public mutating func remove(_ certificate: Certificate) -> Bool {
        let fingerprint = certificate.sha256Fingerprint
        guard let index = certificates.firstIndex(where: { $0.sha256Fingerprint == fingerprint }) else {
            return false
        }
        certificates.remove(at: index)
        return true
    }

    /// Removes the certificate at the specified index.
    ///
    /// - Parameter index: The index of the certificate to remove.
    /// - Returns: The removed certificate.
    @discardableResult
    public mutating func remove(at index: Int) -> Certificate {
        return certificates.remove(at: index)
    }

    /// Removes all certificates from the chain.
    public mutating func removeAll() {
        certificates.removeAll()
    }

    // MARK: - Accessing Certificates

    /// Accesses the certificate at the specified position.
    public subscript(index: Int) -> Certificate {
        get { return certificates[index] }
        set { certificates[index] = newValue }
    }

    /// Returns the certificates as an array.
    public func toArray() -> [Certificate] {
        return certificates
    }

    /// A Boolean indicating whether this chain contains a specific certificate.
    ///
    /// - Parameter certificate: The certificate to look for.
    /// - Returns: `true` if the certificate is in the chain.
    public func contains(_ certificate: Certificate) -> Bool {
        let fingerprint = certificate.sha256Fingerprint
        return certificates.contains { $0.sha256Fingerprint == fingerprint }
    }
}

// MARK: - RandomAccessCollection

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
extension X509CertificateChain: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Certificate

    public var startIndex: Int { 0 }
    public var endIndex: Int { certificates.count }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public func index(before i: Int) -> Int {
        return i - 1
    }
}

// MARK: - ExpressibleByArrayLiteral

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
extension X509CertificateChain: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Certificate...) {
        self.certificates = elements
    }
}

// MARK: - Equatable

@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
extension X509CertificateChain: Equatable {
    public static func == (lhs: X509CertificateChain, rhs: X509CertificateChain) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (a, b) in zip(lhs.certificates, rhs.certificates) {
            if a.sha256Fingerprint != b.sha256Fingerprint {
                return false
            }
        }
        return true
    }
}
