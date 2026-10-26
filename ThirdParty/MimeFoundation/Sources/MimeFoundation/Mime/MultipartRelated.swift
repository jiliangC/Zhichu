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
// MultipartRelated.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with multipart/related entities.
public enum MultipartRelatedError: Error, Equatable, Sendable {
    /// The requested resource was not found.
    case notFound
}

/// A multipart/related MIME entity.
///
/// A ``MultipartRelated`` contains multiple related MIME parts, where one part (the root)
/// references other parts by their Content-ID or Content-Location. This is commonly used
/// for HTML messages with embedded images or other resources.
///
/// The root part is typically an HTML document, and the related parts are resources
/// (such as images) that are referenced from within the HTML using "cid:" URLs.
///
/// ## Topics
///
/// ### Creating Multipart Related Entities
/// - ``init()``
/// - ``init(_:)``
/// - ``init(args:)``
///
/// ### Root Part
/// - ``root``
/// - ``setRoot(_:)``
///
/// ### Finding Related Resources
/// - ``contains(_:)``
/// - ``indexOf(_:)``
/// - ``open(_:)``
/// - ``open(_:mimeType:charset:)``
public final class MultipartRelated: Multipart {
    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    public convenience init(_ args: Any?...) throws {
        try self.init(args: args)
    }

    public init(args: [Any?]) throws {
        try super.init("related")
        try applyArgs(args)
    }

    public convenience init() {
        do {
            try self.init(args: [])
        } catch {
            preconditionFailure("Failed to create multipart/related - this is a programming error")
        }
    }

    /// The root MIME part of the multipart/related entity.
    ///
    /// The root part is typically the main content (such as HTML) that references
    /// other related parts. The root is determined by the "start" parameter in the
    /// Content-Type header, or the "type" parameter, or defaults to the first part.
    public var root: MimeEntity? {
        get {
            let index = rootIndex()
            if index < 0 && count == 0 {
                return nil
            }
            return self[Swift.max(index, 0)]
        }
        set {
            if let newValue {
                _ = try? setRoot(newValue)
            }
        }
    }

    /// Sets the root MIME part of the multipart/related entity.
    ///
    /// Sets the specified entity as the root part and updates the Content-Type
    /// parameters accordingly.
    ///
    /// - Parameter value: The MIME entity to set as the root.
    /// - Throws: An error if the operation fails.
    public func setRoot(_ value: MimeEntity) throws {
        var index = -1

        if count > 0 {
            let rootIndex = self.rootIndex()
            if rootIndex != -1 {
                self[rootIndex] = value
                index = rootIndex
            } else {
                try insert(value, at: 0)
                index = 0
            }
        } else {
            try add(value)
            index = 0
        }

        contentType.parameters["type"] = "\(value.contentType.mediaType)/\(value.contentType.mediaSubtype)"

        if index > 0 {
            if let contentId = value.contentId, !contentId.isEmpty {
                contentType.parameters["start"] = "<\(contentId)>"
            } else {
                let generated = MimeUtils.generateMessageId()
                try? value.setContentId(generated)
                if let contentId = value.contentId, !contentId.isEmpty {
                    contentType.parameters["start"] = "<\(contentId)>"
                }
            }
        } else {
            contentType.parameters["start"] = nil
        }
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    public override func tryGetValue(_ format: TextFormat, body: inout TextPart?) -> Bool {
        if let root = root {
            if let text = root as? TextPart {
                body = text.isFormat(format) ? text : nil
                return body != nil
            }
            if let multipart = root as? Multipart {
                return multipart.tryGetValue(format, body: &body)
            }
        }

        body = nil
        return false
    }

    /// Checks whether the multipart/related contains a part with the specified URI.
    ///
    /// - Parameter uri: The URI to search for (can be a Content-ID or Content-Location).
    /// - Returns: `true` if a part with the specified URI exists; otherwise, `false`.
    public func contains(_ uri: URL) -> Bool {
        return indexOf(uri) != -1
    }

    /// Gets the index of the part with the specified URI.
    ///
    /// Searches for a part that matches the specified URI, which can be either a
    /// Content-ID (using "cid:" scheme) or a Content-Location.
    ///
    /// - Parameter uri: The URI to search for.
    /// - Returns: The index of the matching part, or -1 if not found.
    public func indexOf(_ uri: URL) -> Int {
        return indexOfUri(uri)
    }

    /// Opens the content stream for the part with the specified URI.
    ///
    /// Searches for a part with the specified URI and returns its decoded content stream
    /// along with MIME type and charset information.
    ///
    /// - Parameters:
    ///   - uri: The URI to search for (can be a Content-ID or Content-Location).
    ///   - mimeType: On return, contains the MIME type of the part.
    ///   - charset: On return, contains the charset of the part, if applicable.
    /// - Returns: A stream containing the decoded content.
    /// - Throws: ``MultipartRelatedError/notFound`` if no part with the specified URI exists.
    public func open(_ uri: URL, mimeType: inout String, charset: inout String?) throws -> MimeStream {
        let index = indexOfUri(uri)
        guard index != -1 else {
            throw MultipartRelatedError.notFound
        }

        guard let part = self[index] as? MimePart, let content = part.content else {
            throw MultipartRelatedError.notFound
        }

        mimeType = part.contentType.mimeType
        charset = part.contentType.charset

        return try content.open()
    }

    /// Opens the content stream for the part with the specified URI.
    ///
    /// Searches for a part with the specified URI and returns its decoded content stream.
    ///
    /// - Parameter uri: The URI to search for (can be a Content-ID or Content-Location).
    /// - Returns: A stream containing the decoded content.
    /// - Throws: ``MultipartRelatedError/notFound`` if no part with the specified URI exists.
    public func open(_ uri: URL) throws -> MimeStream {
        let index = indexOfUri(uri)
        guard index != -1 else {
            throw MultipartRelatedError.notFound
        }

        guard let part = self[index] as? MimePart, let content = part.content else {
            throw MultipartRelatedError.notFound
        }

        return try content.open()
    }

    private func rootIndex() -> Int {
        if let start = contentType.parameters["start"] {
            let references = MimeUtils.enumerateReferences(start)
            let contentId = references.first ?? start
            if let cid = URL(string: "cid:\(contentId)") {
                return indexOfUri(cid)
            }
        }

        if let type = contentType.parameters["type"] {
            for index in 0..<count {
                let mimeType = self[index].contentType.mimeType
                if mimeType.caseInsensitiveCompare(type) == .orderedSame {
                    return index
                }
            }
        }

        return -1
    }

    private func indexOfUri(_ uri: URL) -> Int {
        let isAbsolute = uri.scheme != nil
        let isCid = isAbsolute && uri.scheme?.caseInsensitiveCompare("cid") == .orderedSame

        for index in 0..<count {
            let entity = self[index]

            if isAbsolute {
                if isCid {
                    if let contentId = entity.contentId, contentId == uri.path {
                        return index
                    }
                } else if let location = entity.contentLocation {
                    let absolute: URL?
                    if location.scheme == nil {
                        if let base = entity.contentBase ?? contentBase {
                            absolute = URL(string: location.relativeString, relativeTo: base)?.absoluteURL
                        } else {
                            absolute = nil
                        }
                    } else {
                        absolute = location
                    }

                    if let absolute, absolute == uri {
                        return index
                    }
                }
            } else if let location = entity.contentLocation, location == uri {
                return index
            }
        }

        return -1
    }
}
