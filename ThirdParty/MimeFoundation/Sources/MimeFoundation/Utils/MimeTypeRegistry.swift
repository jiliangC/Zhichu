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
// MimeTypeRegistry.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur during MIME type registry operations.
public enum MimeTypeError: Error, Equatable, Sendable {
    /// The MIME type string is empty or contains only whitespace.
    case emptyMimeType

    /// The file extension string is empty or contains only whitespace.
    case emptyExtension
}

/// A registry mapping file extensions to MIME types and vice versa.
///
/// `MimeTypeRegistry` provides a bidirectional mapping between file extensions
/// (like ".jpg", ".txt") and MIME content types (like "image/jpeg", "text/plain").
/// This is useful for determining the appropriate Content-Type header when
/// attaching files to MIME messages.
///
/// ## Default Registry
///
/// A default registry with common file extensions is available:
///
/// ```swift
/// let mimeType = MimeTypeRegistry.default.mimeType(for: "document.pdf")
/// // "application/pdf"
/// ```
///
/// ## Custom Registrations
///
/// Add your own mappings for application-specific file types:
///
/// ```swift
/// var registry = MimeTypeRegistry()
/// try registry.register(mimeType: "application/x-myapp", fileExtension: ".myapp")
/// let type = registry.mimeType(for: "file.myapp")
/// // "application/x-myapp"
/// ```
///
/// ## Reverse Lookup
///
/// Find the file extension for a MIME type:
///
/// ```swift
/// let ext = MimeTypeRegistry.default.extensionFor(mimeType: "image/jpeg")
/// // ".jpg"
/// ```
public struct MimeTypeRegistry: Sendable {
    /// The default registry with common file extension mappings.
    public static var `default`: MimeTypeRegistry { MimeTypeRegistry() }

    /// The MIME type used when no mapping is found for a file extension.
    private static let defaultMimeType = "application/octet-stream"

    private var mimeTypeByExtension: [String: String]
    private var extensionByMimeType: [String: String]

    /// Creates a new MIME type registry with common default mappings.
    ///
    /// The default mappings include common file types such as:
    /// - Text: .txt, .csv, .html
    /// - Images: .jpg, .jpeg, .gif, .png
    /// - Documents: .pdf
    /// - Email: .eml
    public init() {
        self.mimeTypeByExtension = [
            ".txt": "text/plain",
            ".csv": "text/csv",
            ".html": "text/html",
            ".htm": "text/html",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".gif": "image/gif",
            ".png": "image/png",
            ".eml": "message/rfc822",
            ".pdf": "application/pdf"
        ]
        var mapping: [String: String] = [:]
        for (ext, mime) in mimeTypeByExtension {
            if mapping[mime.lowercased()] == nil {
                mapping[mime.lowercased()] = ext
            }
        }
        self.extensionByMimeType = mapping
    }

    /// Returns the MIME type for a given file name.
    ///
    /// Extracts the file extension from the file name and looks up the
    /// corresponding MIME type. If no mapping is found, returns
    /// "application/octet-stream".
    ///
    /// - Parameter fileName: The file name (with or without path).
    /// - Returns: The MIME type string, or "application/octet-stream" if
    ///   no mapping exists for the file extension.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let registry = MimeTypeRegistry.default
    /// registry.mimeType(for: "image.jpg")      // "image/jpeg"
    /// registry.mimeType(for: "/path/to/file.pdf")  // "application/pdf"
    /// registry.mimeType(for: "unknown.xyz")    // "application/octet-stream"
    /// ```
    public func mimeType(for fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.defaultMimeType
        }
        let url = URL(fileURLWithPath: trimmed)
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else {
            return Self.defaultMimeType
        }
        let key = "." + ext
        return mimeTypeByExtension[key] ?? Self.defaultMimeType
    }

    /// Registers a new MIME type and file extension mapping.
    ///
    /// Adds or updates the mapping between a MIME type and a file extension.
    /// If the extension already has a mapping, it is replaced. The extension
    /// is automatically normalized to lowercase and prefixed with a dot if needed.
    ///
    /// - Parameters:
    ///   - mimeType: The MIME type (e.g., "application/x-myapp").
    ///   - fileExtension: The file extension (e.g., ".myapp" or "myapp").
    /// - Throws:
    ///   - ``MimeTypeError/emptyMimeType`` if the MIME type is empty.
    ///   - ``MimeTypeError/emptyExtension`` if the file extension is empty.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var registry = MimeTypeRegistry()
    /// try registry.register(mimeType: "application/x-custom", fileExtension: ".custom")
    /// try registry.register(mimeType: "text/x-special", fileExtension: "spc")  // Dot added automatically
    /// ```
    public mutating func register(mimeType: String, fileExtension: String) throws {
        let trimmedMime = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMime.isEmpty else {
            throw MimeTypeError.emptyMimeType
        }
        let trimmedExt = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExt.isEmpty else {
            throw MimeTypeError.emptyExtension
        }
        let normalizedExt = trimmedExt.hasPrefix(".") ? trimmedExt.lowercased() : "." + trimmedExt.lowercased()
        mimeTypeByExtension[normalizedExt] = trimmedMime
        extensionByMimeType[trimmedMime.lowercased()] = normalizedExt
    }

    /// Returns the file extension for a given MIME type.
    ///
    /// Performs a reverse lookup to find the file extension associated with
    /// a MIME type. If multiple extensions map to the same MIME type, returns
    /// the first one that was registered.
    ///
    /// - Parameter mimeType: The MIME type to look up.
    /// - Returns: The file extension (including the leading dot), or `nil` if
    ///   no mapping exists.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let registry = MimeTypeRegistry.default
    /// registry.extensionFor(mimeType: "image/jpeg")  // ".jpg"
    /// registry.extensionFor(mimeType: "text/plain")  // ".txt"
    /// registry.extensionFor(mimeType: "unknown/type")  // nil
    /// ```
    public func extensionFor(mimeType: String) -> String? {
        let trimmed = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return extensionByMimeType[trimmed.lowercased()]
    }
}
