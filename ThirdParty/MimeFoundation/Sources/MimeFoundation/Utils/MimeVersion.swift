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
// MimeVersion.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// Represents a MIME version number.
///
/// `MimeVersion` represents the version number found in the MIME-Version header
/// of MIME messages. The standard MIME version is "1.0", but this type supports
/// version numbers with 2 to 4 components for flexibility.
///
/// ## Parsing MIME Versions
///
/// Use ``MimeUtils/tryParseVersion(_:)-1ygnx`` to parse version strings:
///
/// ```swift
/// if let version = MimeUtils.tryParseVersion("1.0") {
///     print(version)  // "1.0"
/// }
/// ```
///
/// ## Version Components
///
/// The version is stored as an array of integer components. For example:
/// - "1.0" -> `[1, 0]`
/// - "1.0.0" -> `[1, 0, 0]`
/// - "1.0.0.0" -> `[1, 0, 0, 0]`
public struct MimeVersion: Equatable, CustomStringConvertible, Sendable {
    /// The version number components.
    ///
    /// For a version string like "1.0", this array contains `[1, 0]`.
    /// The array always contains between 2 and 4 elements.
    public let components: [Int]

    /// Creates a new MIME version from the specified components.
    ///
    /// - Parameter components: An array of 2 to 4 integer version components.
    /// - Returns: A new `MimeVersion`, or `nil` if the component count is invalid.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let version = MimeVersion(components: [1, 0])
    /// print(version!)  // "1.0"
    /// ```
    public init?(components: [Int]) {
        guard (2...4).contains(components.count) else {
            return nil
        }
        self.components = components
    }

    /// A string representation of the version number.
    ///
    /// Returns the components joined by periods, e.g., "1.0" or "1.0.0".
    public var description: String {
        components.map(String.init).joined(separator: ".")
    }
}
