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
// X509CertificateRecordFields.swift
//
// Field selection flags for certificate record queries.
//

import Foundation

/// Field selection flags for X.509 certificate record queries.
///
/// These flags are used to specify which fields should be included when
/// querying certificate records from a database. This allows for efficient
/// queries that only retrieve the necessary data.
///
/// ## Usage
///
/// ```swift
/// let fields: X509CertificateRecordFields = [.id, .certificate, .trusted]
/// let records = database.find(fingerprint: "abc123", fields: fields)
/// ```
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public struct X509CertificateRecordFields: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Include the record ID.
    public static let id = X509CertificateRecordFields(rawValue: 1 << 0)

    /// Include the trusted flag.
    public static let trusted = X509CertificateRecordFields(rawValue: 1 << 1)

    /// Include the S/MIME capabilities algorithms.
    public static let algorithms = X509CertificateRecordFields(rawValue: 1 << 2)

    /// Include the algorithms updated timestamp.
    public static let algorithmsUpdated = X509CertificateRecordFields(rawValue: 1 << 3)

    /// Include the certificate data.
    public static let certificate = X509CertificateRecordFields(rawValue: 1 << 4)

    /// Include the private key data.
    public static let privateKey = X509CertificateRecordFields(rawValue: 1 << 5)

    /// All fields.
    public static let all: X509CertificateRecordFields = [
        .id, .trusted, .algorithms, .algorithmsUpdated, .certificate, .privateKey
    ]
}
