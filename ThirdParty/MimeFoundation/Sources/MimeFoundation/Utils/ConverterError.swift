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
// ConverterError.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during content converter operations.
///
/// These errors are used by the content converter system when registering
/// or attempting to use converters for transforming MIME content.
public enum ConverterError: Error, Equatable, Sendable {
    /// A converter for the specified format is already registered.
    ///
    /// This error occurs when attempting to register a converter that conflicts
    /// with an existing converter registration.
    case alreadyRegistered

    /// The requested conversion is not supported.
    ///
    /// This error occurs when attempting to convert content in a format
    /// for which no converter has been registered.
    case notSupported
}
