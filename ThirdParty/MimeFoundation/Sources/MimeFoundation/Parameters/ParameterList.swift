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
// ParameterList.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Errors that can occur when working with a ``ParameterList``.
public enum ParameterListError: Error, Equatable, Sendable {
    /// A parameter with the specified name already exists in the list.
    ///
    /// - Parameter name: The duplicate parameter name.
    case duplicateName(String)

    /// The specified index is out of the valid range.
    ///
    /// - Parameters:
    ///   - index: The index that was requested.
    ///   - count: The number of elements in the list.
    case indexOutOfRange(index: Int, count: Int)

    /// The destination array does not have sufficient capacity.
    ///
    /// - Parameters:
    ///   - required: The number of elements required.
    ///   - available: The available capacity in the destination array.
    case insufficientCapacity(required: Int, available: Int)
}

/// A list of parameters, as found in the Content-Type and Content-Disposition headers.
///
/// Parameters are used by both ``ContentType`` and ``ContentDisposition``.
///
/// ## Overview
///
/// ``ParameterList`` provides a collection of ``Parameter`` objects, typically used
/// to store additional attributes for Content-Type and Content-Disposition headers.
/// Common parameters include "charset", "boundary", "filename", and "name".
///
/// ## Example
///
/// ```swift
/// let params = ParameterList()
/// try params.add("charset", "utf-8")
/// try params.add("boundary", "----boundary123")
///
/// // Access by name
/// if let charset = params["charset"] {
///     print("Charset: \(charset)")
/// }
/// ```
public final class ParameterList: RandomAccessCollection, MutableCollection, RangeReplaceableCollection, ExpressibleByArrayLiteral, Equatable {
    public typealias Element = Parameter
    public typealias Index = Int

    private var parameters: [Parameter]

    internal var changed: ((ParameterList) -> Void)?

    /// Creates a new empty parameter list.
    ///
    /// Creates a new ``ParameterList`` with no parameters.
    public init() {
        self.parameters = []
    }

    /// Creates a new parameter list from an array literal.
    ///
    /// - Parameter elements: The parameters to include in the list.
    public init(arrayLiteral elements: Parameter...) {
        self.parameters = []
        for element in elements {
            attach(element)
            self.parameters.append(element)
        }
    }

    /// The starting index of the collection.
    public var startIndex: Int { parameters.startIndex }

    /// The ending index of the collection.
    public var endIndex: Int { parameters.endIndex }

    /// Returns the index after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    ///
    /// - Returns: The index immediately after `i`.
    public func index(after i: Int) -> Int {
        parameters.index(after: i)
    }

    /// The number of parameters in the list.
    public var count: Int { parameters.count }

    /// A Boolean value indicating whether the list is read-only.
    ///
    /// This property always returns `false` for ``ParameterList``.
    public var isReadOnly: Bool { false }

    /// Accesses the parameter at the specified position.
    ///
    /// - Parameter position: The index of the parameter to access.
    ///
    /// - Returns: The parameter at the specified index.
    ///
    /// - Precondition: `position` must be a valid index (0 <= position < count).
    /// - Precondition: When setting, the new parameter's name must not duplicate
    ///                 an existing parameter at a different index.
    public subscript(position: Int) -> Parameter {
        get {
            precondition(position >= 0 && position < parameters.count, "Index out of range")
            return parameters[position]
        }
        set {
            guard position >= 0 && position < parameters.count else {
                preconditionFailure("Index out of range")
            }
            let nameKey = newValue.name.lowercased()
            if let existing = indexOfName(nameKey), existing != position {
                preconditionFailure("Duplicate parameter name")
            }
            detach(parameters[position])
            attach(newValue)
            parameters[position] = newValue
            onChanged()
        }
    }

    /// Gets or sets the value of a parameter with the specified name.
    ///
    /// When getting, returns the value of the parameter with the specified name
    /// (case-insensitive), or `nil` if no such parameter exists.
    ///
    /// When setting, if the parameter exists, its value is updated; if a non-nil
    /// value is provided and no parameter exists, a new parameter is added; if `nil`
    /// is provided, the parameter is removed.
    ///
    /// - Parameter name: The parameter name.
    ///
    /// - Returns: The value of the parameter, or `nil` if not found.
    public subscript(name: String) -> String? {
        get {
            guard let index = indexOfName(name) else {
                return nil
            }
            return parameters[index].value
        }
        set {
            if let value = newValue {
                if let index = indexOfName(name) {
                    if parameters[index].value == value {
                        return
                    }
                    parameters[index].value = value
                } else if let param = try? Parameter(name, value) {
                    _ = try? add(param)
                }
            } else {
                if indexOfName(name) != nil {
                    _ = remove(name)
                }
            }
        }
    }

    /// Adds a parameter to the list.
    ///
    /// Adds the specified parameter to the end of the list.
    ///
    /// - Parameter parameter: The parameter to add.
    ///
    /// - Throws: ``ParameterListError/duplicateName(_:)`` if a parameter with the
    ///           same name already exists.
    public func add(_ parameter: Parameter) throws {
        if indexOfName(parameter.name) != nil {
            throw ParameterListError.duplicateName(parameter.name)
        }
        attach(parameter)
        parameters.append(parameter)
        onChanged()
    }

    /// Adds a parameter with the specified name and value.
    ///
    /// Creates a new parameter with the given name and value, then adds it to the list.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    ///
    /// - Throws: ``ParameterError/emptyName`` if the name is empty.
    /// - Throws: ``ParameterError/invalidName`` if the name contains illegal characters.
    /// - Throws: ``ParameterListError/duplicateName(_:)`` if a parameter with the
    ///           same name already exists.
    public func add(_ name: String, _ value: String) throws {
        let parameter = try Parameter(name, value)
        try add(parameter)
    }

    /// Adds a parameter with the specified encoding, name, and value.
    ///
    /// Creates a new parameter with the given encoding, name, and value,
    /// then adds it to the list.
    ///
    /// - Parameters:
    ///   - encoding: The character encoding to use.
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    ///
    /// - Throws: ``ParameterError/emptyName`` if the name is empty.
    /// - Throws: ``ParameterError/invalidName`` if the name contains illegal characters.
    /// - Throws: ``ParameterListError/duplicateName(_:)`` if a parameter with the
    ///           same name already exists.
    public func add(encoding: String.Encoding, name: String, value: String) throws {
        let parameter = try Parameter(encoding: encoding, name: name, value: value)
        try add(parameter)
    }

    /// Adds a parameter with the specified charset, name, and value.
    ///
    /// Creates a new parameter with the given charset, name, and value,
    /// then adds it to the list.
    ///
    /// - Parameters:
    ///   - charset: The charset name (e.g., "utf-8", "iso-8859-1").
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    ///
    /// - Throws: ``ParameterError/emptyName`` if the name is empty.
    /// - Throws: ``ParameterError/invalidName`` if the name contains illegal characters.
    /// - Throws: ``ParameterError/unsupportedCharset(_:)`` if the charset is not supported.
    /// - Throws: ``ParameterListError/duplicateName(_:)`` if a parameter with the
    ///           same name already exists.
    public func add(charset: String, name: String, value: String) throws {
        let parameter = try Parameter(charset: charset, name: name, value: value)
        try add(parameter)
    }

    /// Checks if the list contains the specified parameter.
    ///
    /// Uses identity comparison (===) rather than equality comparison.
    ///
    /// - Parameter parameter: The parameter to search for.
    ///
    /// - Returns: `true` if the list contains the parameter; otherwise, `false`.
    public func contains(_ parameter: Parameter) -> Bool {
        parameters.contains(where: { $0 === parameter })
    }

    /// Checks if the list contains a parameter with the specified name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter name: The parameter name to search for.
    ///
    /// - Returns: `true` if the list contains a parameter with the name;
    ///            otherwise, `false`.
    public func contains(_ name: String) -> Bool {
        indexOfName(name) != nil
    }

    /// Copies the parameters to an array, starting at the specified index.
    ///
    /// - Parameters:
    ///   - array: The destination array.
    ///   - arrayIndex: The starting index in the destination array.
    ///
    /// - Throws: ``ParameterListError/indexOutOfRange(index:count:)``
    ///           if `arrayIndex` is out of range.
    /// - Throws: ``ParameterListError/insufficientCapacity(required:available:)``
    ///           if the destination array does not have enough capacity.
    public func copyTo(_ array: inout [Parameter], startingAt arrayIndex: Int) throws {
        guard arrayIndex >= 0, arrayIndex <= array.count else {
            throw ParameterListError.indexOutOfRange(index: arrayIndex, count: array.count)
        }
        guard arrayIndex + parameters.count <= array.count else {
            throw ParameterListError.insufficientCapacity(required: arrayIndex + parameters.count, available: array.count)
        }
        for (offset, param) in parameters.enumerated() {
            array[arrayIndex + offset] = param
        }
    }

    /// Gets the index of the specified parameter.
    ///
    /// Uses identity comparison (===) rather than equality comparison.
    ///
    /// - Parameter parameter: The parameter to search for.
    ///
    /// - Returns: The index of the parameter, or -1 if not found.
    public func indexOf(_ parameter: Parameter) -> Int {
        parameters.firstIndex(where: { $0 === parameter }) ?? -1
    }

    /// Gets the index of the parameter with the specified name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter name: The parameter name to search for.
    ///
    /// - Returns: The index of the parameter, or -1 if not found.
    public func indexOf(_ name: String) -> Int {
        indexOfName(name) ?? -1
    }

    /// Inserts a parameter at the specified index.
    ///
    /// - Parameters:
    ///   - index: The index at which to insert the parameter.
    ///   - parameter: The parameter to insert.
    ///
    /// - Throws: ``ParameterListError/indexOutOfRange(index:count:)``
    ///           if the index is out of range.
    /// - Throws: ``ParameterListError/duplicateName(_:)`` if a parameter with the
    ///           same name already exists.
    public func insert(at index: Int, _ parameter: Parameter) throws {
        guard index >= 0 && index <= parameters.count else {
            throw ParameterListError.indexOutOfRange(index: index, count: parameters.count)
        }
        if indexOfName(parameter.name) != nil {
            throw ParameterListError.duplicateName(parameter.name)
        }
        attach(parameter)
        parameters.insert(parameter, at: index)
        onChanged()
    }

    /// Inserts a parameter with the specified name and value at the given index.
    ///
    /// Creates a new parameter with the given name and value, then inserts it
    /// at the specified index.
    ///
    /// - Parameters:
    ///   - index: The index at which to insert the parameter.
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    ///
    /// - Throws: ``ParameterError/emptyName`` if the name is empty.
    /// - Throws: ``ParameterError/invalidName`` if the name contains illegal characters.
    /// - Throws: ``ParameterListError/indexOutOfRange(index:count:)``
    ///           if the index is out of range.
    /// - Throws: ``ParameterListError/duplicateName(_:)`` if a parameter with the
    ///           same name already exists.
    public func insert(at index: Int, name: String, value: String) throws {
        let parameter = try Parameter(name, value)
        try insert(at: index, parameter)
    }

    /// Removes the specified parameter from the list.
    ///
    /// Uses identity comparison (===) rather than equality comparison.
    ///
    /// - Parameter parameter: The parameter to remove.
    ///
    /// - Returns: `true` if the parameter was found and removed; otherwise, `false`.
    @discardableResult
    public func remove(_ parameter: Parameter) -> Bool {
        guard let index = parameters.firstIndex(where: { $0 === parameter }) else {
            return false
        }
        detach(parameters[index])
        parameters.remove(at: index)
        onChanged()
        return true
    }

    /// Removes the parameter with the specified name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter name: The name of the parameter to remove.
    ///
    /// - Returns: `true` if the parameter was found and removed; otherwise, `false`.
    @discardableResult
    public func remove(_ name: String) -> Bool {
        guard let index = indexOfName(name) else {
            return false
        }
        detach(parameters[index])
        parameters.remove(at: index)
        onChanged()
        return true
    }

    /// Removes the parameter at the specified index.
    ///
    /// - Parameter index: The index of the parameter to remove.
    ///
    /// - Throws: ``ParameterListError/indexOutOfRange(index:count:)``
    ///           if the index is out of range.
    public func removeAt(_ index: Int) throws {
        guard index >= 0 && index < parameters.count else {
            throw ParameterListError.indexOutOfRange(index: index, count: parameters.count)
        }
        detach(parameters[index])
        parameters.remove(at: index)
        onChanged()
    }

    /// Removes all parameters from the list.
    public func clear() {
        for param in parameters {
            detach(param)
        }
        parameters.removeAll(keepingCapacity: true)
        onChanged()
    }

    /// Replaces the specified subrange of parameters with the given collection.
    ///
    /// - Parameters:
    ///   - subrange: The range of parameters to replace.
    ///   - newElements: The new parameters to insert.
    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == Parameter {
        for i in subrange {
            detach(parameters[i])
        }
        let newArray = Array(newElements)
        for param in newArray {
            attach(param)
        }
        parameters.replaceSubrange(subrange, with: newArray)
        onChanged()
    }

    /// Gets the parameter with the specified name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter name: The parameter name to search for.
    ///
    /// - Returns: The parameter with the specified name, or `nil` if not found.
    public func parameter(named name: String) -> Parameter? {
        guard let index = indexOfName(name) else {
            return nil
        }
        return parameters[index]
    }

    /// Gets the value of the parameter with the specified name.
    ///
    /// The comparison is case-insensitive.
    ///
    /// - Parameter name: The parameter name to search for.
    ///
    /// - Returns: The value of the parameter, or `nil` if not found.
    public func value(forParameterNamed name: String) -> String? {
        guard let index = indexOfName(name) else {
            return nil
        }
        return parameters[index].value
    }

    /// Returns a string representation of the parameter list.
    ///
    /// Formats all parameters as "; name=value" pairs.
    ///
    /// - Returns: A string containing all formatted parameters.
    public func toString() -> String {
        var builder = ValueStringBuilder(initialCapacity: 128)
        writeTo(&builder)
        return builder.asString()
    }

    internal func writeTo(_ builder: inout ValueStringBuilder) {
        for param in parameters {
            builder.append("; ")
            param.writeTo(&builder)
        }
    }

    internal func encode(_ options: FormatOptions, builder: inout ValueStringBuilder, lineLength: inout Int, charset: String.Encoding) {
        for param in parameters {
            param.encode(options, builder: &builder, lineLength: &lineLength, charset: charset)
        }
    }

    private struct NameValuePair {
        let valueLength: Int
        let valueStart: Int
        let encoded: Bool
        let value: [UInt8]
        let name: String
        let id: Int?
    }

    private static func skipParamName(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let start = index
        while index < endIndex && ByteClassification.isAttr(text[index]) {
            index += 1
        }
        return index > start
    }

    private static func tryParseNameValuePair(
        _ options: ParserOptions,
        _ text: [UInt8],
        index: inout Int,
        endIndex: Int,
        throwOnError: Bool,
        pair: inout NameValuePair?
    ) throws -> Bool {
        var encoded = false
        var id: Int? = nil
        pair = nil

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        let startIndex = index
        if !skipParamName(text, index: &index, endIndex: endIndex) {
            if throwOnError {
                throw ParseException("Invalid parameter name token at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        let name = String(bytes: text[startIndex..<index], encoding: .ascii) ?? ""

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete parameter at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        if text[index] == 0x2A { // '*'
            index += 1

            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex {
                if throwOnError {
                    throw ParseException("Incomplete parameter at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                }
                return false
            }

            var identifier = 0
            if ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &identifier) {
                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }
                if index >= endIndex {
                    if throwOnError {
                        throw ParseException("Incomplete parameter at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                    }
                    return false
                }
                if text[index] == 0x2A {
                    encoded = true
                    index += 1
                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                        return false
                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Incomplete parameter at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
                        }
                        return false
                    }
                }
                id = identifier
            } else {
                encoded = true
            }
        }

        if text[index] != 0x3D { // '='
            if throwOnError {
                throw ParseException("Incomplete parameter at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        index += 1

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
            return false
        }

        if index >= endIndex {
            if throwOnError {
                throw ParseException("Incomplete parameter at offset \(startIndex)", tokenIndex: startIndex, errorIndex: index)
            }
            return false
        }

        var valueIndex = index
        var value = text
        var valueLength = 0

        if text[index] == 0x22 {
            _ = try ParseUtils.skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)
            valueLength = index - valueIndex
        } else if options.parameterComplianceMode == .strict {
            _ = ParseUtils.skipToken(text, index: &index, endIndex: endIndex)
            valueLength = index - valueIndex
        } else {
            while index < endIndex && text[index] != 0x3B && text[index] != 0x0D && text[index] != 0x0A {
                index += 1
            }
            valueLength = index - valueIndex

            if index < endIndex && text[index] != 0x3B {
                var buffer = ByteArrayBuilder(initialCapacity: 256)
                buffer.append(text, startIndex: valueIndex, count: valueLength)

                repeat {
                    while index < endIndex && (text[index] == 0x0D || text[index] == 0x0A) {
                        index += 1
                    }
                    valueIndex = index
                    while index < endIndex && text[index] != 0x3B && text[index] != 0x0D && text[index] != 0x0A {
                        index += 1
                    }
                    buffer.append(text, startIndex: valueIndex, count: index - valueIndex)
                } while index < endIndex && text[index] != 0x3B

                value = buffer.toArray()
                valueLength = value.count
                valueIndex = 0
            }

            while valueLength > valueIndex && ByteClassification.isWhitespace(value[valueLength - 1]) {
                valueLength -= 1
            }
        }

        pair = NameValuePair(
            valueLength: valueLength,
            valueStart: valueIndex,
            encoded: encoded,
            value: value,
            name: name,
            id: id
        )
        return true
    }

    private static func tryGetCharset(_ text: [UInt8], index: inout Int, endIndex: Int) -> String? {
        let startIndex = index
        var charsetEnd = 0
        var i = index

        while i < endIndex {
            if text[i] == 0x27 { // '\''
                break
            }
            i += 1
        }
        if i == startIndex || i == endIndex {
            return nil
        }
        charsetEnd = i

        i += 1
        while i < endIndex {
            if text[i] == 0x27 {
                break
            }
            i += 1
        }
        if i == endIndex {
            return nil
        }

        let charset = String(bytes: text[startIndex..<charsetEnd], encoding: .ascii) ?? ""
        index = i + 1
        return charset
    }

    private static func decodeRfc2231Bytes(
        _ text: [UInt8],
        startIndex: Int,
        count: Int,
        isFirstSegment: Bool,
        encoding: inout String.Encoding?
    ) -> [UInt8] {
        var index = startIndex
        let endIndex = startIndex + count
        if isFirstSegment {
            if let charset = tryGetCharset(text, index: &index, endIndex: endIndex) {
                if let resolved = CharsetUtils.getEncoding(charset) {
                    encoding = resolved
                } else {
                    encoding = .isoLatin1
                }
            } else if encoding == nil {
                encoding = .isoLatin1
            }
        }

        let hex = HexDecoder()
        let length = endIndex - index
        let outputLength = hex.estimateOutputLength(length)
        var output = Array(repeating: UInt8(0), count: outputLength)
        let written = (try? hex.decode(text, startIndex: index, length: length, output: &output)) ?? 0
        return Array(output.prefix(written))
    }

    internal static func tryParse(
        _ options: ParserOptions,
        _ text: [UInt8],
        index: inout Int,
        endIndex: Int,
        throwOnError: Bool,
        paramList: inout ParameterList?
    ) throws -> Bool {
        var rfc2231: [String: [NameValuePair]] = [:]
        var params: [NameValuePair] = []
        paramList = nil

        while true {
            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if index >= endIndex {
                break
            }

            if text[index] == 0x3B {
                index += 1
                continue
            }

            var pair: NameValuePair?
            if !(try tryParseNameValuePair(options, text, index: &index, endIndex: endIndex, throwOnError: throwOnError, pair: &pair)) {
                return false
            }

            guard let parsed = pair else {
                return false
            }

            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                return false
            }

            if parsed.id != nil {
                var list = rfc2231[parsed.name] ?? []
                let isFirst = list.isEmpty
                list.append(parsed)
                rfc2231[parsed.name] = list
                if isFirst {
                    params.append(parsed)
                }
            } else {
                params.append(parsed)
            }

            if index >= endIndex {
                break
            }

            if text[index] != 0x3B {
                if options.parameterComplianceMode == .strict {
                    if throwOnError {
                        throw ParseException("Invalid parameter list token at offset \(index)", tokenIndex: index, errorIndex: index)
                    }
                    return false
                }
            } else {
                index += 1
            }
        }

        let list = ParameterList()

        for param in params {
            var method: ParameterEncodingMethod = .default
            var startIndex = param.valueStart
            var length = param.valueLength
            var buffer = param.value
            var encoding: String.Encoding? = nil
            var value = ""

            if let _ = param.id, let parts = rfc2231[param.name] {
                method = .rfc2231
                let sorted = parts.sorted { (lhs, rhs) -> Bool in
                    (lhs.id ?? -1) < (rhs.id ?? -1)
                }

                var pendingBytes: [UInt8] = []
                for (idx, part) in sorted.enumerated() {
                    startIndex = part.valueStart
                    length = part.valueLength
                    buffer = part.value

                    if part.encoded {
                        if length >= 2 && buffer[startIndex] == 0x22 && buffer[startIndex + length - 1] == 0x22 {
                            startIndex += 1
                            length -= 2
                        }
                        let decoded = decodeRfc2231Bytes(buffer, startIndex: startIndex, count: length, isFirstSegment: idx == 0, encoding: &encoding)
                        pendingBytes.append(contentsOf: decoded)

                        let isLastEncoded = idx + 1 >= sorted.count || !sorted[idx + 1].encoded
                        if isLastEncoded {
                            let decodedString = String(data: Data(pendingBytes), encoding: encoding ?? .isoLatin1)
                                ?? String(decoding: pendingBytes, as: UTF8.self)
                            value.append(decodedString)
                            pendingBytes.removeAll(keepingCapacity: true)
                        }
                    } else if length >= 2 && buffer[startIndex] == 0x22 {
                        if !pendingBytes.isEmpty {
                            let decodedString = String(data: Data(pendingBytes), encoding: encoding ?? .isoLatin1)
                                ?? String(decoding: pendingBytes, as: UTF8.self)
                            value.append(decodedString)
                            pendingBytes.removeAll(keepingCapacity: true)
                        }
                        let quoted = CharsetUtils.convertToUnicode(options, buffer, start: startIndex, length: length)
                        value.append(MimeUtils.unquote(quoted))
                    } else if length > 0 {
                        if !pendingBytes.isEmpty {
                            let decodedString = String(data: Data(pendingBytes), encoding: encoding ?? .isoLatin1)
                                ?? String(decoding: pendingBytes, as: UTF8.self)
                            value.append(decodedString)
                            pendingBytes.removeAll(keepingCapacity: true)
                        }
                        value.append(CharsetUtils.convertToUnicode(options, buffer, start: startIndex, length: length))
                    }
                }

                if !pendingBytes.isEmpty {
                    let decodedString = String(data: Data(pendingBytes), encoding: encoding ?? .isoLatin1)
                        ?? String(decoding: pendingBytes, as: UTF8.self)
                    value.append(decodedString)
                }
            } else if param.encoded {
                if length >= 2 && buffer[startIndex] == 0x22 {
                    if buffer[startIndex + length - 1] == 0x22 {
                        length -= 1
                    }
                    startIndex += 1
                    length -= 1
                }
                let decodedBytes = decodeRfc2231Bytes(buffer, startIndex: startIndex, count: length, isFirstSegment: true, encoding: &encoding)
                value = String(data: Data(decodedBytes), encoding: encoding ?? .isoLatin1)
                    ?? String(decoding: decodedBytes, as: UTF8.self)
                method = .rfc2231
            } else if list.contains(param.name) {
                continue
            } else {
                var codepage = -1
                if length >= 2 && buffer[startIndex] == 0x22 {
                    let unquoted = MimeUtils.unquote(buffer, startIndex: startIndex, length: length)
                    value = Rfc2047.decodeText(options, unquoted, startIndex: 0, count: unquoted.count, codepage: &codepage)
                } else if length > 0 {
                    value = Rfc2047.decodeText(options, buffer, startIndex: startIndex, count: length, codepage: &codepage)
                } else {
                    value = ""
                }

                if codepage != -1 && codepage != 65001 {
                    encoding = CharsetUtils.getEncodingOrDefault(codepage, fallback: .utf8)
                    method = .rfc2047
                }
            }

            let existingIndex = list.indexOf(param.name)
            if existingIndex != -1 {
                let existing = list[existingIndex]
                if let encoding {
                    existing.encoding = encoding
                }
                existing.value = value
                existing.encodingMethod = method
                continue
            }

            if let encoding {
                _ = try? list.add(encoding: encoding, name: param.name, value: value)
            } else {
                _ = try? list.add(param.name, value)
            }
            let nameIndex = list.indexOf(param.name)
            if nameIndex != -1 {
                list[nameIndex].encodingMethod = method
            }
        }

        paramList = list
        return true
    }

    private func indexOfName(_ name: String) -> Int? {
        let key = name.lowercased()
        return parameters.firstIndex(where: { $0.name.lowercased() == key })
    }

    private func attach(_ parameter: Parameter) {
        parameter.changed = { [weak self] _ in
            self?.onChanged()
        }
    }

    private func detach(_ parameter: Parameter) {
        parameter.changed = nil
    }

    private func onChanged() {
        changed?(self)
    }

    /// Determines whether two parameter lists are equal.
    ///
    /// Two parameter lists are considered equal if they contain the same parameters
    /// (matched by name, case-insensitive) with the same values, regardless of order.
    ///
    /// - Parameters:
    ///   - lhs: The first parameter list to compare.
    ///   - rhs: The second parameter list to compare.
    ///
    /// - Returns: `true` if the parameter lists are equal; otherwise, `false`.
    public static func == (lhs: ParameterList, rhs: ParameterList) -> Bool {
        guard lhs.parameters.count == rhs.parameters.count else {
            return false
        }
        for param in lhs.parameters {
            guard let rhsIndex = rhs.indexOfName(param.name) else {
                return false
            }
            if param != rhs.parameters[rhsIndex] {
                return false
            }
        }
        return true
    }
}
