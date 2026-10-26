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
// Multipart.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with multipart entities.
public enum MultipartError: Error, Equatable, Sendable {
    /// The multipart subtype cannot be empty.
    case emptySubtype

    /// An invalid argument was provided.
    case invalidArgument

    /// The specified index is out of range.
    case indexOutOfRange

    /// The maximum line length value is invalid.
    case invalidMaxLineLength
}

/// A multipart MIME entity.
///
/// A ``Multipart`` entity is a MIME entity that contains one or more child MIME entities.
/// Common subtypes include multipart/mixed, multipart/alternative, multipart/related,
/// and multipart/signed.
///
/// The child entities are separated by a boundary string specified in the Content-Type
/// header. The multipart may also contain optional preamble and epilogue text that
/// appears before the first boundary and after the last boundary, respectively.
///
/// ## Topics
///
/// ### Creating Multipart Entities
/// - ``init(_:)``
/// - ``init()``
/// - ``init(_:_:)``
/// - ``init(_:args:)``
///
/// ### Managing Child Parts
/// - ``add(_:)``
/// - ``insert(_:at:)``
/// - ``remove(_:)``
/// - ``remove(at:)``
/// - ``clear()``
/// - ``contains(_:)``
/// - ``indexOf(_:)``
///
/// ### Multipart Properties
/// - ``boundary``
/// - ``preamble``
/// - ``epilogue``
/// - ``writeEndBoundary``
///
/// ### Collection Conformance
/// - ``count``
/// - ``subscript(_:)``
/// - ``startIndex``
/// - ``endIndex``
///
/// ### Preparing for Transport
/// - ``prepare(_:maxLineLength:)``
open class Multipart: MimeEntity, RandomAccessCollection, MutableCollection {
    public typealias Element = MimeEntity
    public typealias Index = Int

    private var children: [MimeEntity] = []
    private var preambleStorage: String?
    private var epilogueStorage: String?
    private var writeEndBoundaryStorage: Bool = true
    internal var rawBody: [UInt8]? = nil

    private var rawEndBoundaryStorage: [UInt8]?

    public var rawEndBoundary: [UInt8]? {
        get { rawEndBoundaryStorage }
        set {
            rawEndBoundaryStorage = newValue
            if let newValue, newValue.isEmpty {
                writeEndBoundaryStorage = false
            }
        }
    }

    public var writeEndBoundary: Bool {
        writeEndBoundaryStorage
    }

    public var isReadOnly: Bool { false }

    public var startIndex: Int { children.startIndex }
    public var endIndex: Int { children.endIndex }

    public func index(after i: Int) -> Int { children.index(after: i) }

    public subscript(position: Int) -> MimeEntity {
        get { children[position] }
        set {
            precondition(position >= 0 && position < children.count, "index out of range")
            children[position] = newValue
        }
    }

    public var count: Int { children.count }

    /// The boundary string used to separate child parts.
    ///
    /// The boundary is specified in the Content-Type header and is used to delimit
    /// the child parts within the multipart entity.
    public var boundary: String {
        contentType.boundary ?? ""
    }

    /// The preamble text that appears before the first boundary.
    ///
    /// The preamble is text that appears before the first boundary in the multipart
    /// body. It is typically used to provide information for non-MIME clients.
    public var preamble: String? {
        get { preambleStorage }
        set {
            rawBody = nil
            if let value = newValue {
                preambleStorage = Multipart.foldPreambleOrEpilogue(.default, value, isEpilogue: false)
            } else {
                preambleStorage = nil
            }
        }
    }

    /// The epilogue text that appears after the last boundary.
    ///
    /// The epilogue is text that appears after the final boundary in the multipart
    /// body. It is typically used to provide information for non-MIME clients.
    public var epilogue: String? {
        get { epilogueStorage }
        set {
            rawBody = nil
            if let value = newValue {
                epilogueStorage = Multipart.foldPreambleOrEpilogue(.default, value, isEpilogue: true)
                writeEndBoundaryStorage = true
            } else {
                epilogueStorage = nil
            }
        }
    }

    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    /// Initializes a new multipart entity with the specified subtype.
    ///
    /// Creates a new multipart entity with the media type "multipart" and the specified
    /// subtype. A boundary string is automatically generated.
    ///
    /// - Parameter subtype: The media subtype (e.g., "mixed", "alternative", "related").
    /// - Throws: ``MultipartError/emptySubtype`` if the subtype is empty.
    public init(_ subtype: String) throws {
        if subtype.isEmpty {
            throw MultipartError.emptySubtype
        }
        let contentType = try ContentType("multipart", subtype)
        super.init(contentType)
        contentType.boundary = Multipart.generateBoundary()
    }

    public convenience init(_ subtype: String, _ args: Any?...) throws {
        try self.init(subtype, args: args)
    }

    public convenience init(_ subtype: String, args: [Any?]) throws {
        try self.init(subtype)
        try applyArgs(args)
    }

    /// Initializes a new multipart/mixed entity.
    ///
    /// Creates a new multipart/mixed entity with an automatically generated boundary.
    public convenience init() {
        do {
            try self.init("mixed")
        } catch {
            preconditionFailure("Failed to create multipart/mixed - this is a programming error")
        }
    }

    public func setBoundary(_ value: String) {
        rawBody = nil
        contentType.boundary = value
    }

    /// Adds a child entity to the multipart.
    ///
    /// - Parameter entity: The MIME entity to add.
    /// - Throws: An error if adding fails.
    public func add(_ entity: MimeEntity) throws {
        rawBody = nil
        children.append(entity)
    }

    /// Inserts a child entity at the specified index.
    ///
    /// - Parameters:
    ///   - entity: The MIME entity to insert.
    ///   - index: The index at which to insert the entity.
    /// - Throws: ``MultipartError/indexOutOfRange`` if the index is invalid.
    public func insert(_ entity: MimeEntity, at index: Int) throws {
        guard index >= 0 && index <= children.count else {
            throw MultipartError.indexOutOfRange
        }
        rawBody = nil
        children.insert(entity, at: index)
    }

    /// Removes the specified child entity from the multipart.
    ///
    /// - Parameter entity: The MIME entity to remove.
    /// - Returns: `true` if the entity was found and removed; otherwise, `false`.
    @discardableResult
    public func remove(_ entity: MimeEntity) -> Bool {
        guard let index = children.firstIndex(where: { $0 === entity }) else {
            return false
        }
        children.remove(at: index)
        return true
    }

    public func remove(at index: Int) throws {
        guard index >= 0 && index < children.count else {
            throw MultipartError.indexOutOfRange
        }
        rawBody = nil
        children.remove(at: index)
    }

    public func contains(_ entity: MimeEntity) -> Bool {
        return children.contains(where: { $0 === entity })
    }

    public func indexOf(_ entity: MimeEntity) -> Int {
        return children.firstIndex(where: { $0 === entity }) ?? -1
    }

    public func setItem(at index: Int, _ entity: MimeEntity) throws {
        guard index >= 0 && index < children.count else {
            throw MultipartError.indexOutOfRange
        }
        children[index] = entity
    }

    public func clear() {
        rawBody = nil
        children.removeAll(keepingCapacity: true)
    }

    public func copyTo(_ array: inout [MimeEntity], at index: Int) throws {
        guard index >= 0 && index <= array.count else {
            throw MultipartError.indexOutOfRange
        }
        array.insert(contentsOf: children, at: index)
    }

    public func prepare(_ constraint: EncodingConstraint, maxLineLength: Int = FormatOptions.defaultMaxLineLength) throws {
        if maxLineLength < FormatOptions.minimumLineLength || maxLineLength > FormatOptions.maximumLineLength {
            throw MultipartError.invalidMaxLineLength
        }
        for child in children {
            if let part = child as? MimePart {
                try part.prepare(constraint)
            } else if let messagePart = child as? MessagePart {
                try messagePart.prepare(constraint, maxLineLength: maxLineLength)
            } else if let multipart = child as? Multipart {
                try multipart.prepare(constraint, maxLineLength: maxLineLength)
            }
        }
    }

    open override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    open func tryGetValue(_ format: TextFormat, body: inout TextPart?) -> Bool {
        for index in 0..<count {
            if let multipart = children[index] as? Multipart {
                if multipart.tryGetValue(format, body: &body) {
                    return true
                }
                break
            }

            if let text = children[index] as? TextPart, !text.isAttachment {
                if text.isFormat(format) {
                    body = text
                    return true
                }
                break
            }
        }

        body = nil
        return false
    }

    public override func writeTo(_ options: FormatOptions, _ stream: MimeStream) throws {
        try super.writeTo(options, stream)
    }

    internal override func writeBody(_ options: FormatOptions, stream: MimeStream) throws {
        guard let boundary = contentType.boundary else {
            if let preamble = preambleStorage {
                let bytes = Array(preamble.utf8)
                try stream.write(bytes, offset: 0, count: bytes.count)
            }
            if let epilogue = epilogueStorage {
                let bytes = Array(epilogue.utf8)
                try stream.write(bytes, offset: 0, count: bytes.count)
            }
            return
        }

        if let preamble = preambleStorage {
            let bytes = Array(preamble.utf8)
            try stream.write(bytes, offset: 0, count: bytes.count)
        }

        let newLine = options.newLine
        for part in children {
            let boundaryLine = "--\(boundary)\(newLine)"
            let boundaryBytes = Array(boundaryLine.utf8)
            try stream.write(boundaryBytes, offset: 0, count: boundaryBytes.count)
            try part.writeTo(options, stream)
            if shouldWriteNewLine(after: part) {
                let newLineBytes = Array(newLine.utf8)
                try stream.write(newLineBytes, offset: 0, count: newLineBytes.count)
            }
        }

        if writeEndBoundaryStorage {
            let endLine = "--\(boundary)--\(newLine)"
            let endBytes = Array(endLine.utf8)
            try stream.write(endBytes, offset: 0, count: endBytes.count)
        }

        if let epilogue = epilogueStorage {
            let bytes = Array(epilogue.utf8)
            try stream.write(bytes, offset: 0, count: bytes.count)
        }
    }

    public static func foldPreambleOrEpilogue(_ options: FormatOptions, _ text: String, isEpilogue: Bool) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var outputLines: [String] = []
        let maxLineLength = options.maxLineLength

        for line in lines {
            if line.isEmpty {
                outputLines.append("")
                continue
            }
            outputLines.append(contentsOf: wrapLine(String(line), maxLineLength: maxLineLength))
        }

        var result = outputLines.joined(separator: options.newLine)
        if !result.isEmpty && !result.hasSuffix(options.newLine) {
            result.append(options.newLine)
        }
        if isEpilogue && !result.hasPrefix(options.newLine) {
            result = options.newLine + result
        }
        return result
    }

    private static func wrapLine(_ line: String, maxLineLength: Int) -> [String] {
        var result: [String] = []
        var remaining = line
        while remaining.count > maxLineLength {
            let splitIndex = remaining.index(remaining.startIndex, offsetBy: maxLineLength)
            var breakIndex = remaining[..<splitIndex].lastIndex(of: " ")
            if breakIndex == nil {
                breakIndex = splitIndex
            }
            let head = remaining[..<breakIndex!]
            result.append(String(head))
            var tailStart = breakIndex!
            if tailStart < remaining.endIndex, remaining[tailStart] == " " {
                tailStart = remaining.index(after: tailStart)
            }
            remaining = String(remaining[tailStart...])
            if remaining.isEmpty {
                break
            }
        }
        if !remaining.isEmpty {
            result.append(remaining)
        }
        return result
    }

    private static func generateBoundary() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "=-\(uuid)"
    }

    private func shouldWriteNewLine(after part: MimeEntity) -> Bool {
        if let mimePart = part as? MimePart {
            return mimePart.content != nil
        }
        if let messagePart = part as? MessagePart {
            return messagePart.message?.body != nil
        }
        if let multipart = part as? Multipart {
            return multipart.writeEndBoundary
        }
        return true
    }

    private func tryInit(_ obj: Any) -> Bool {
        if let header = obj as? Header {
            headers.add(header)
            return true
        }
        if let headers = obj as? [Header] {
            for header in headers {
                self.headers.add(header)
            }
            return true
        }
        return false
    }

    internal func applyArgs(_ args: [Any?]) throws {
        for obj in args {
            guard let obj else { continue }
            if tryInit(obj) {
                continue
            }
            if let entity = obj as? MimeEntity {
                try add(entity)
                continue
            }
            throw MultipartError.invalidArgument
        }
    }
}
