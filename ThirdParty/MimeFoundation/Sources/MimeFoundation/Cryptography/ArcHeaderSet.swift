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
// ArcHeaderSet.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A class that groups related ARC headers by instance number.
///
/// Each ARC chain instance (i=1, i=2, etc.) consists of three headers:
/// - ARC-Authentication-Results
/// - ARC-Message-Signature
/// - ARC-Seal
///
/// This class collects and tracks these three headers for a single instance.
public final class ArcHeaderSet {
    /// The ARC-Authentication-Results header for this instance.
    public internal(set) var arcAuthenticationResults: Header?

    /// The ARC-Message-Signature header for this instance.
    public internal(set) var arcMessageSignature: Header?

    /// The parsed parameters from the ARC-Message-Signature header.
    public internal(set) var arcMessageSignatureParameters: [String: String]?

    /// The ARC-Seal header for this instance.
    public internal(set) var arcSeal: Header?

    /// The parsed parameters from the ARC-Seal header.
    public internal(set) var arcSealParameters: [String: String]?

    /// Creates a new empty ARC header set.
    public init() {}

    /// Adds a header to this set.
    ///
    /// - Parameters:
    ///   - header: The header to add.
    ///   - parameters: The parsed parameters from the header (for AMS and AS headers).
    /// - Returns: `true` if the header was added successfully; `false` if a duplicate was detected.
    internal func add(header: Header, parameters: [String: String]? = nil) -> Bool {
        switch header.id {
        case .arcAuthenticationResults:
            if arcAuthenticationResults != nil {
                return false
            }
            arcAuthenticationResults = header
            return true

        case .arcMessageSignature:
            if arcMessageSignature != nil {
                return false
            }
            arcMessageSignature = header
            arcMessageSignatureParameters = parameters
            return true

        case .arcSeal:
            if arcSeal != nil {
                return false
            }
            arcSeal = header
            arcSealParameters = parameters
            return true

        default:
            return false
        }
    }

    /// Checks if all three required headers are present.
    public var isComplete: Bool {
        arcAuthenticationResults != nil && arcMessageSignature != nil && arcSeal != nil
    }

    /// Gets any validation errors for missing headers in this set.
    internal var missingHeaderErrors: ArcValidationErrors {
        var errors: ArcValidationErrors = []
        if arcAuthenticationResults == nil {
            errors.insert(.missingArcAuthenticationResults)
        }
        if arcMessageSignature == nil {
            errors.insert(.missingArcMessageSignature)
        }
        if arcSeal == nil {
            errors.insert(.missingArcSeal)
        }
        return errors
    }
}
