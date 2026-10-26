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
// SecureMimeType.swift
//
// S/MIME type enumeration for identifying cryptographic content types.
//

import Foundation

/// Represents the type of S/MIME content.
public enum SecureMimeType: String, Sendable, Equatable, Hashable {
    /// Unknown or unrecognized S/MIME type.
    case unknown = "unknown"

    /// Compressed data (RFC 3274).
    case compressedData = "compressed-data"

    /// Enveloped (encrypted) data (RFC 5652).
    case envelopedData = "enveloped-data"

    /// Signed data (RFC 5652).
    case signedData = "signed-data"

    /// Certificate-only message (RFC 5652).
    case certsOnly = "certs-only"

    /// Authenticated enveloped data (RFC 5083).
    case authEnvelopedData = "authEnveloped-data"

    /// Initializes from the smime-type parameter value.
    /// - Parameter smimeType: The smime-type parameter string.
    public init(smimeType: String?) {
        guard let smimeType = smimeType?.lowercased().trimmingCharacters(in: .whitespaces) else {
            self = .unknown
            return
        }

        switch smimeType {
        case "compressed-data":
            self = .compressedData
        case "enveloped-data":
            self = .envelopedData
        case "signed-data":
            self = .signedData
        case "certs-only":
            self = .certsOnly
        case "authenveloped-data":
            self = .authEnvelopedData
        default:
            self = .unknown
        }
    }
}
