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
// DefaultSecureMimeContext.swift
//
// Default implementation of SecureMimeContext using swift-certificates.
//

import Foundation
@_spi(CMS) import X509

/// Default implementation of `SecureMimeContext`.
///
/// This class provides a concrete implementation of S/MIME signing and
/// verification using the swift-certificates library's CMS APIs.
@available(macOS 11.0, iOS 14, tvOS 14, watchOS 7, macCatalyst 14, *)
public final class DefaultSecureMimeContext: SecureMimeContext, @unchecked Sendable {

    /// Shared instance of the default S/MIME context.
    public static let shared = DefaultSecureMimeContext()

    /// Creates a new default S/MIME context.
    public override init() {
        super.init()
    }
}
