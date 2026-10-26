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
// TnefException.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A TNEF exception.
///
/// A ``TnefException`` occurs when a TNEF stream is found to be corrupted and
/// cannot be read any further. The ``errorStatus`` property indicates the specific
/// compliance issue that caused the exception.
public final class TnefException: Error, LocalizedError {
    /// The compliance status error that caused the exception.
    ///
    /// This property indicates which specific compliance issue was encountered
    /// when parsing the TNEF stream. See ``TnefComplianceStatus`` for possible values.
    public let errorStatus: TnefComplianceStatus

    /// The error message describing what went wrong.
    ///
    /// This optional message provides additional context about the error that occurred.
    public let message: String?

    /// The inner error that caused this exception, if any.
    ///
    /// When the TNEF exception was caused by another underlying error,
    /// this property contains that original error.
    public let innerError: Error?

    /// Initialize a new instance of the ``TnefException`` class.
    ///
    /// Creates a new ``TnefException`` with the specified error status and optional message.
    ///
    /// - Parameters:
    ///   - errorStatus: The compliance status error.
    ///   - message: The error message describing what went wrong.
    ///   - innerError: The inner error that caused this exception, if any.
    public init(_ errorStatus: TnefComplianceStatus, _ message: String? = nil, innerError: Error? = nil) {
        self.errorStatus = errorStatus
        self.message = message
        self.innerError = innerError
    }

    /// A localized description of the error.
    ///
    /// Returns the ``message`` property value for use with Swift's error handling system.
    public var errorDescription: String? {
        message
    }
}
