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
// DigestAlgorithm.swift
//
// Digest algorithm enumeration for S/MIME signing.
//

import Foundation

/// A cryptographic digest (hash) algorithm.
///
/// Digest algorithms are secure hashing algorithms that are used to generate
/// unique fixed-length signatures for arbitrary data.
///
/// The most commonly used digest algorithms are currently MD5 and SHA-1, however,
/// MD5 was successfully broken in 2008 and should be avoided. In late 2013,
/// Microsoft announced that they would be retiring their use of SHA-1 in their
/// products by 2016 with the assumption that its days as an unbroken digest
/// algorithm were numbered.
///
/// Microsoft and other vendors have moved to the SHA-2 suite of digest algorithms
/// which includes SHA-224, SHA-256, SHA-384, and SHA-512.
///
/// ## Recommendations
///
/// - Use ``sha256`` or stronger for all new implementations
/// - Avoid ``md5`` and ``sha1`` unless required for compatibility
/// - ``sha256`` provides a good balance of security and performance
///
/// ## Topics
///
/// ### Secure Algorithms (Recommended)
/// - ``sha256``
/// - ``sha384``
/// - ``sha512``
///
/// ### Legacy Algorithms (Avoid if Possible)
/// - ``sha1``
/// - ``md5``
public enum DigestAlgorithm: String, Sendable, Equatable, Hashable, CaseIterable {
    /// No digest algorithm specified.
    ///
    /// This value indicates that no algorithm has been selected or that the
    /// algorithm is unknown.
    case none = "none"

    /// The MD5 digest algorithm.
    ///
    /// - Warning: MD5 was successfully broken in 2008 and should not be used
    ///   for security-sensitive applications. Use ``sha256`` or stronger instead.
    case md5 = "md5"

    /// The SHA-1 digest algorithm.
    ///
    /// - Warning: SHA-1 is considered weak and vulnerable to collision attacks.
    ///   It should not be used for new implementations. Use ``sha256`` or
    ///   stronger instead.
    case sha1 = "sha1"

    /// The SHA-256 digest algorithm.
    ///
    /// This is the recommended digest algorithm for most use cases. It provides
    /// a good balance of security (256-bit output) and performance.
    case sha256 = "sha256"

    /// The SHA-384 digest algorithm.
    ///
    /// This algorithm provides 384-bit output and is suitable for applications
    /// requiring higher security margins than SHA-256.
    case sha384 = "sha384"

    /// The SHA-512 digest algorithm.
    ///
    /// This algorithm provides 512-bit output and offers the highest security
    /// level in the SHA-2 family.
    case sha512 = "sha512"

    /// The default digest algorithm.
    ///
    /// Returns ``sha256``, which is the recommended algorithm for most applications.
    public static var `default`: DigestAlgorithm { .sha256 }

    /// The micalg parameter value for this digest algorithm.
    ///
    /// The micalg (Message Integrity Check Algorithm) parameter is used in
    /// `multipart/signed` messages to indicate the digest algorithm used for
    /// signing. This property returns the appropriate string value for use
    /// in MIME headers.
    ///
    /// For example:
    /// - ``sha256`` returns `"sha-256"`
    /// - ``sha1`` returns `"sha-1"`
    /// - ``md5`` returns `"md5"`
    public var micalg: String {
        switch self {
        case .none:
            return ""
        case .md5:
            return "md5"
        case .sha1:
            return "sha-1"
        case .sha256:
            return "sha-256"
        case .sha384:
            return "sha-384"
        case .sha512:
            return "sha-512"
        }
    }

    /// Creates a ``DigestAlgorithm`` from a micalg parameter string.
    ///
    /// This initializer parses the micalg parameter value commonly found in
    /// `multipart/signed` MIME headers and returns the corresponding algorithm.
    ///
    /// - Parameter micalg: The micalg parameter value (e.g., `"sha-256"`, `"sha-1"`).
    ///   If `nil` or unrecognized, ``none`` is returned.
    ///
    /// ## Example
    /// ```swift
    /// let algorithm = DigestAlgorithm(micalg: "sha-256")
    /// // algorithm == .sha256
    /// ```
    public init(micalg: String?) {
        guard let micalg = micalg?.lowercased().trimmingCharacters(in: .whitespaces) else {
            self = .none
            return
        }

        switch micalg {
        case "md5":
            self = .md5
        case "sha-1", "sha1":
            self = .sha1
        case "sha-256", "sha256":
            self = .sha256
        case "sha-384", "sha384":
            self = .sha384
        case "sha-512", "sha512":
            self = .sha512
        default:
            self = .none
        }
    }

    /// Creates a ``DigestAlgorithm`` from an OID (Object Identifier) string.
    ///
    /// This initializer parses ASN.1 Object Identifier strings commonly found
    /// in X.509 certificates and CMS/PKCS#7 structures.
    ///
    /// - Parameter oid: The OID string (e.g., `"2.16.840.1.101.3.4.2.1"` for SHA-256).
    ///   If unrecognized, ``none`` is returned.
    ///
    /// ## Common OIDs
    /// | Algorithm | OID |
    /// |-----------|-----|
    /// | MD5 | 1.2.840.113549.2.5 |
    /// | SHA-1 | 1.3.14.3.2.26 |
    /// | SHA-256 | 2.16.840.1.101.3.4.2.1 |
    /// | SHA-384 | 2.16.840.1.101.3.4.2.2 |
    /// | SHA-512 | 2.16.840.1.101.3.4.2.3 |
    public init(oid: String) {
        switch oid {
        case "1.2.840.113549.2.5":
            self = .md5
        case "1.3.14.3.2.26":
            self = .sha1
        case "2.16.840.1.101.3.4.2.1":
            self = .sha256
        case "2.16.840.1.101.3.4.2.2":
            self = .sha384
        case "2.16.840.1.101.3.4.2.3":
            self = .sha512
        default:
            self = .none
        }
    }

    /// The OID (Object Identifier) for this digest algorithm.
    ///
    /// Returns the ASN.1 Object Identifier string for this algorithm, suitable
    /// for use in X.509 certificates and CMS/PKCS#7 structures.
    ///
    /// Returns an empty string for ``none``.
    public var oid: String {
        switch self {
        case .none:
            return ""
        case .md5:
            return "1.2.840.113549.2.5"
        case .sha1:
            return "1.3.14.3.2.26"
        case .sha256:
            return "2.16.840.1.101.3.4.2.1"
        case .sha384:
            return "2.16.840.1.101.3.4.2.2"
        case .sha512:
            return "2.16.840.1.101.3.4.2.3"
        }
    }
}
