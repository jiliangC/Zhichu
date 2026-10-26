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
// AuthenticationResults.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum AuthenticationResultsError: Error, Equatable, Sendable {
    case invalidRange
}

/// A parsed representation of the Authentication-Results header.
///
/// The Authentication-Results header is used with electronic mail messages to
/// indicate the results of message authentication efforts. Any receiver-side
/// software, such as mail filters or Mail User Agents (MUAs), can use this header
/// field to relay that information in a convenient and meaningful way to users or
/// to make sorting and filtering decisions.
public struct AuthenticationResults: Codable, Hashable, Sendable {
    /// The authentication service identifier.
    ///
    /// The authentication service identifier is the `authserv-id` token
    /// as defined in [RFC 7601](https://tools.ietf.org/html/rfc7601).
    public var authenticationServiceIdentifier: String?

    /// The instance value.
    ///
    /// This value will only be set if the `AuthenticationResults`
    /// represents an ARC-Authentication-Results header value.
    public var instance: Int?

    /// The Authentication-Results version.
    ///
    /// The version value is the `authres-version` token as defined in
    /// [RFC 7601](https://tools.ietf.org/html/rfc7601).
    public var version: Int?

    /// The list of authentication results.
    public var results: [AuthenticationMethodResult]

    internal init() {
        self.authenticationServiceIdentifier = nil
        self.instance = nil
        self.version = nil
        self.results = []
    }

    /// Initialize a new instance of `AuthenticationResults`.
    ///
    /// - Parameter authservId: The authentication service identifier.
    public init(_ authservId: String) {
        self.authenticationServiceIdentifier = authservId
        self.instance = nil
        self.version = nil
        self.results = []
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case authenticationServiceIdentifier, instance, version, results
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.authenticationServiceIdentifier = try container.decodeIfPresent(String.self, forKey: .authenticationServiceIdentifier)
        self.instance = try container.decodeIfPresent(Int.self, forKey: .instance)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
        self.results = try container.decode([AuthenticationMethodResult].self, forKey: .results)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(authenticationServiceIdentifier, forKey: .authenticationServiceIdentifier)
        try container.encodeIfPresent(instance, forKey: .instance)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encode(results, forKey: .results)
    }

    public func encode(_ options: FormatOptions, _ builder: inout String, lineLength: Int) {
        var lineLength = lineLength
        var space = 1

        if let instance {
            let value = String(instance)
            builder.append(" i=")
            builder.append(value)
            builder.append(";")
            lineLength += 4 + value.count
        }

        if let authservId = authenticationServiceIdentifier {
            if lineLength + space + authservId.count > options.maxLineLength {
                builder.append(options.newLine)
                builder.append("\t")
                lineLength = 1
                space = 0
            }

            if space > 0 {
                builder.append(" ")
                lineLength += 1
            }

            builder.append(authservId)
            lineLength += authservId.count

            if let version {
                let versionText = String(version)
                if lineLength + 1 + versionText.count > options.maxLineLength {
                    builder.append(options.newLine)
                    builder.append("\t")
                    lineLength = 1
                } else {
                    builder.append(" ")
                    lineLength += 1
                }

                builder.append(versionText)
                lineLength += versionText.count
            }

            builder.append(";")
            lineLength += 1
        }

        if !results.isEmpty {
            for index in results.indices {
                if index > 0 {
                    builder.append(";")
                    lineLength += 1
                }

                results[index].encode(options, builder: &builder, lineLength: &lineLength)
            }
        } else {
            builder.append(" none")
        }

        builder.append(options.newLine)
    }

    /// Serialize the `AuthenticationResults` to a string.
    ///
    /// Creates a string-representation of the `AuthenticationResults`.
    ///
    /// - Returns: The serialized string.
    public func toString() -> String {
        var builder = ValueStringBuilder(initialCapacity: 256)
        writeTo(&builder)
        return builder.toString()
    }

    internal func writeTo(_ builder: inout ValueStringBuilder) {
        if let instance {
            builder.append("i=")
            builder.append(String(instance))
            builder.append("; ")
        }

        if let authservId = authenticationServiceIdentifier {
            builder.append(authservId)

            if let version {
                builder.append(" ")
                builder.append(String(version))
            }

            builder.append("; ")
        }

        if !results.isEmpty {
            for index in results.indices {
                if index > 0 {
                    builder.append("; ")
                }

                results[index].writeTo(&builder)
            }
        } else {
            builder.append("none")
        }
    }

    private static func isKeyword(_ c: UInt8) -> Bool {
        (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x5F
    }

    private static func skipKeyword(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let startIndex = index
        while index < endIndex && isKeyword(text[index]) {
            index += 1
        }
        return index > startIndex
    }

    private static func skipValue(_ text: [UInt8], index: inout Int, endIndex: Int, quoted: inout Bool) throws -> Bool {
        if text[index] == 0x22 { // '"'
            quoted = true
            return try ParseUtils.skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: false)
        }

        quoted = false
        return ParseUtils.skipToken(text, index: &index, endIndex: endIndex)
    }

    private static func skipDotMethodOrOffice365AuthServId(_ text: [UInt8], index: inout Int, endIndex: Int) -> Bool {
        let startIndex = index

        while skipKeyword(text, index: &index, endIndex: endIndex), index < endIndex, text[index] == 0x2E {
            index += 1
        }

        if index > startIndex && text[index - 1] != 0x2E {
            return true
        }

        return false
    }

    private static func skipPropertyValue(_ text: [UInt8], index: inout Int, endIndex: Int, quoted: inout Bool) throws -> Bool {
        if text[index] == 0x22 { // '"'
            quoted = true
            return try ParseUtils.skipQuoted(text, index: &index, endIndex: endIndex, throwOnError: false)
        }

        quoted = false

        while index < endIndex && !ByteClassification.isWhitespace(text[index]) && text[index] != 0x3B && text[index] != 0x28 {
            index += 1
        }

        return true
    }

    private static func tryParseMethods(_ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool, authres: inout AuthenticationResults) throws -> Bool {
        var value = ""
        var quoted = false

        while index < endIndex {
            var srvid: String? = nil

            methodToken: while true {
                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }

                if index >= endIndex {
                    return true
                }

                let methodIndex = index

                if !skipKeyword(text, index: &index, endIndex: endIndex) {
                    if throwOnError {
                        throw ParseException("Invalid method token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                    }
                    return false
                }

                if srvid == nil && index < endIndex && text[index] == 0x2E {
                    index += 1

                    if !skipDotMethodOrOffice365AuthServId(text, index: &index, endIndex: endIndex) {
                        if throwOnError {
                            throw ParseException("Invalid Office365 authserv-id token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                        }
                        return false
                    }

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                        return false
                    }

                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Missing semi-colon after Office365 authserv-id token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                        }
                        return false
                    }

                    if text[index] == 0x3B {
                        srvid = String(decoding: text[methodIndex..<index], as: UTF8.self)
                        index += 1
                        continue methodToken
                    } else if text[index] == 0x3D || text[index] == 0x2F {
                        // method name with dots, continue
                    } else {
                        if throwOnError {
                            throw ParseException("Unexpected token after Office365 authserv-id token at offset \(index)", tokenIndex: index, errorIndex: index)
                        }
                        return false
                    }
                }

                let method = String(decoding: text[methodIndex..<index], as: UTF8.self)

                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                    return false

                }
                if index >= endIndex {
                    if method != "none" {
                        if throwOnError {
                            throw ParseException("Incomplete methodspec token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                        }
                        return false
                    }

                    if !authres.results.isEmpty {
                        if throwOnError {
                            throw ParseException("Invalid no-result token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                        }
                        return false
                    }

                    return true
                }

                var resinfo = AuthenticationMethodResult(method)
                resinfo.office365AuthenticationServiceIdentifier = srvid
                authres.results.append(resinfo)
                let resinfoIndex = authres.results.count - 1

                var tokenIndex: Int

                if text[index] == 0x2F {
                    index += 1

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    tokenIndex = index
                    var version = 0
                    if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &version) {
                        if throwOnError {
                            throw ParseException("Invalid method-version token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    authres.results[resinfoIndex].version = version

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Incomplete methodspec token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                        }
                        return false
                    }
                }

                if text[index] != 0x3D {
                    if throwOnError {
                        throw ParseException("Invalid methodspec token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                    }
                    return false
                }

                index += 1

                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                    return false

                }
                if index >= endIndex {
                    if throwOnError {
                        throw ParseException("Incomplete methodspec token at offset \(methodIndex)", tokenIndex: methodIndex, errorIndex: index)
                    }
                    return false
                }

                tokenIndex = index

                if !skipKeyword(text, index: &index, endIndex: endIndex) {
                    if throwOnError {
                        throw ParseException("Invalid result token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                    }
                    return false
                }

                authres.results[resinfoIndex].result = String(decoding: text[tokenIndex..<index], as: UTF8.self)

                _ = ParseUtils.skipWhiteSpace(text, index: &index, endIndex: endIndex)

                if index < endIndex && text[index] == 0x28 {
                    let commentIndex = index

                    if !ParseUtils.skipComment(text, index: &index, endIndex: endIndex) {
                        if throwOnError {
                            throw ParseException("Incomplete comment token at offset \(commentIndex)", tokenIndex: commentIndex, errorIndex: index)
                        }
                        return false
                    }

                    let start = commentIndex + 1
                    let comment = String(decoding: text[start..<(index - 1)], as: UTF8.self)
                    authres.results[resinfoIndex].resultComment = Header.unfold(comment)

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                }

                if index >= endIndex {
                    return true
                }

                if text[index] == 0x3B {
                    index += 1
                    break
                }

                tokenIndex = index

                if !skipKeyword(text, index: &index, endIndex: endIndex) {
                    if throwOnError {
                        throw ParseException("Invalid reasonspec or propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                    }
                    return false
                }

                value = String(decoding: text[tokenIndex..<index], as: UTF8.self)

                if value == "reason" || value == "action" {
                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                        return false
                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Incomplete \(value)spec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    if text[index] != 0x3D {
                        if throwOnError {
                            throw ParseException("Invalid \(value)spec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    index += 1

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    let reasonIndex = index

                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Invalid \(value)spec value token at offset \(reasonIndex)", tokenIndex: reasonIndex, errorIndex: index)
                        }
                        return false
                    }
                    if !(try skipValue(text, index: &index, endIndex: endIndex, quoted: &quoted)) {
                        if throwOnError {
                            throw ParseException("Invalid \(value)spec value token at offset \(reasonIndex)", tokenIndex: reasonIndex, errorIndex: index)
                        }
                        return false
                    }

                    var reason = String(decoding: text[reasonIndex..<index], as: UTF8.self)

                    if quoted {
                        reason = MimeUtils.unquote(reason, convertTabsToSpaces: true)
                    }

                    if value == "action" {
                        authres.results[resinfoIndex].action = reason
                    } else {
                        authres.results[resinfoIndex].reason = reason
                    }

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex {
                        return true
                    }

                    if text[index] == 0x3B {
                        index += 1
                        break
                    }

                    tokenIndex = index

                    if !skipKeyword(text, index: &index, endIndex: endIndex) {
                        if throwOnError {
                            throw ParseException("Invalid propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    value = String(decoding: text[tokenIndex..<index], as: UTF8.self)
                }

                while true {
                    let ptype = value

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Incomplete propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    if text[index] != 0x2E {
                        if throwOnError {
                            throw ParseException("Invalid propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    index += 1

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Incomplete propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    let propertyIndex = index

                    if !skipKeyword(text, index: &index, endIndex: endIndex) {
                        if throwOnError {
                            throw ParseException("Invalid property token at offset \(propertyIndex)", tokenIndex: propertyIndex, errorIndex: index)
                        }
                        return false
                    }

                    let property = String(decoding: text[propertyIndex..<index], as: UTF8.self)

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Incomplete propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    if text[index] != 0x3D {
                        if throwOnError {
                            throw ParseException("Invalid propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    index += 1

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    let valueIndex = index

                    if index >= text.count {
                        if throwOnError {
                            throw ParseException("Incomplete propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }
                    if !(try skipPropertyValue(text, index: &index, endIndex: endIndex, quoted: &quoted)) {
                        if throwOnError {
                            throw ParseException("Incomplete propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    var propValue = String(decoding: text[valueIndex..<index], as: UTF8.self)

                    if quoted {
                        propValue = MimeUtils.unquote(propValue, convertTabsToSpaces: true)
                    }

                    let propspec = AuthenticationMethodProperty(ptype: ptype, property: property, value: propValue, quoted: quoted)
                    authres.results[resinfoIndex].properties.append(propspec)

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex || text[index] == 0x3B {
                        break
                    }

                    tokenIndex = index

                    if !skipKeyword(text, index: &index, endIndex: endIndex) {
                        if throwOnError {
                            throw ParseException("Invalid propspec token at offset \(tokenIndex)", tokenIndex: tokenIndex, errorIndex: index)
                        }
                        return false
                    }

                    value = String(decoding: text[tokenIndex..<index], as: UTF8.self)
                }

                if index < endIndex, text[index] == 0x3B {
                    index += 1
                }

                break
            }
        }

        return true
    }

    private static func tryParse(_ text: [UInt8], index: inout Int, endIndex: Int, throwOnError: Bool, authres: inout AuthenticationResults?) throws -> Bool {
        var instance: Int? = nil
        var srvid: String? = nil
        var value = ""

        authres = nil

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

            return false

        }
        repeat {
            let start = index
            var quoted = false

            if index >= endIndex {
                if throwOnError {
                    throw ParseException("Incomplete authserv-id token at offset \(start)", tokenIndex: start, errorIndex: index)
                }
                return false
            }
            if !(try skipValue(text, index: &index, endIndex: endIndex, quoted: &quoted)) {
                if throwOnError {
                    throw ParseException("Incomplete authserv-id token at offset \(start)", tokenIndex: start, errorIndex: index)
                }
                return false
            }

            value = String(decoding: text[start..<index], as: UTF8.self)

            if quoted {
                srvid = MimeUtils.unquote(value, convertTabsToSpaces: true)
            } else {
                if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {
                    return false
                }
                if index < endIndex && text[index] == 0x3D {
                    if instance != nil {
                        if throwOnError {
                            throw ParseException("Invalid token at offset \(start)", tokenIndex: start, errorIndex: index)
                        }
                        return false
                    }

                    if value != "i" {
                        var temp = AuthenticationResults()
                        index = 0
                        let result = try tryParseMethods(text, index: &index, endIndex: endIndex, throwOnError: throwOnError, authres: &temp)
                        authres = temp
                        return result
                    }

                    index += 1

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    let instanceStart = index
                    var parsedInstance = 0

                    if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &parsedInstance) {
                        if throwOnError {
                            throw ParseException("Invalid instance value at offset \(instanceStart)", tokenIndex: instanceStart, errorIndex: index)
                        }
                        return false
                    }

                    instance = parsedInstance

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                    if index >= endIndex {
                        if throwOnError {
                            throw ParseException("Missing semi-colon after instance value at offset \(instanceStart)", tokenIndex: instanceStart, errorIndex: index)
                        }
                        return false
                    }

                    if text[index] != 0x3B {
                        if throwOnError {
                            throw ParseException("Unexpected token after instance value at offset \(index)", tokenIndex: index, errorIndex: index)
                        }
                        return false
                    }

                    index += 1

                    if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                        return false

                    }
                } else {
                    srvid = value
                }
            }
        } while srvid == nil

        var parsed = AuthenticationResults(srvid!)
        parsed.instance = instance

        if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

            return false

        }
        if index >= endIndex {
            authres = parsed
            return true
        }

        if text[index] != 0x3B {
            let start = index
            var parsedVersion = 0

            if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &parsedVersion) {
                if throwOnError {
                    throw ParseException("Invalid authres-version at offset \(start)", tokenIndex: start, errorIndex: index)
                }
                return false
            }

            parsed.version = parsedVersion

            if !(try ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: throwOnError)) {

                return false

            }
            if index >= endIndex {
                authres = parsed
                return true
            }

            if text[index] != 0x3B {
                if throwOnError {
                    throw ParseException("Unknown token at offset \(index)", tokenIndex: index, errorIndex: index)
                }
                return false
            }
        }

        index += 1

        let result = try tryParseMethods(text, index: &index, endIndex: endIndex, throwOnError: throwOnError, authres: &parsed)
        authres = parsed
        return result
    }

    // MARK: - Swift-Idiomatic Parsing Initializers

    /// Parse the specified text into a new `AuthenticationResults` instance.
    ///
    /// Parses an Authentication-Results header value from the supplied text.
    ///
    /// - Parameter text: The text to parse.
    /// - Throws: ``ParseException`` if the text could not be parsed.
    public init(parsing text: String) throws {
        let buffer = Array(text.utf8)
        try self.init(parsing: buffer)
    }

    /// Parse the specified input buffer into a new `AuthenticationResults` instance.
    ///
    /// Parses an Authentication-Results header value from the supplied buffer.
    ///
    /// - Parameter buffer: The input buffer.
    /// - Throws: ``ParseException`` if the buffer could not be parsed.
    public init(parsing buffer: [UInt8]) throws {
        var authres: AuthenticationResults? = nil
        var index = 0
        if try Self.tryParse(buffer, index: &index, endIndex: buffer.count, throwOnError: true, authres: &authres), let parsed = authres {
            self = parsed
        } else {
            throw ParseException("Failed to parse authentication results.", tokenIndex: 0, errorIndex: index)
        }
    }
}

/// An authentication method results.
///
/// Represents the result of a single authentication method (e.g., SPF, DKIM, DMARC).
public struct AuthenticationMethodResult: Codable, Hashable, Sendable {
    /// The Office365 method-specific authserv-id.
    ///
    /// Instead of specifying a single authentication service identifier at the
    /// beginning of the header value, Office365 seems to provide a different
    /// authentication service identifier for each method.
    public var office365AuthenticationServiceIdentifier: String?

    /// The authentication method.
    public let method: String

    /// The authentication method version.
    public var version: Int?

    /// The authentication method results.
    public var result: String

    /// The comment regarding the authentication method result.
    public var resultComment: String?

    /// The action taken for the authentication method result.
    public var action: String?

    /// The reason for the authentication method result.
    public var reason: String?

    /// The properties used by the authentication method.
    public var properties: [AuthenticationMethodProperty]

    internal init(_ method: String) {
        self.method = method
        self.result = ""
        self.properties = []
    }

    /// Initialize a new instance of `AuthenticationMethodResult`.
    ///
    /// - Parameters:
    ///   - method: The method used for authentication.
    ///   - result: The result of the authentication method.
    public init(_ method: String, _ result: String) {
        self.method = method
        self.result = result
        self.properties = []
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case office365AuthenticationServiceIdentifier, method, version, result, resultComment, action, reason, properties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.office365AuthenticationServiceIdentifier = try container.decodeIfPresent(String.self, forKey: .office365AuthenticationServiceIdentifier)
        self.method = try container.decode(String.self, forKey: .method)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
        self.result = try container.decode(String.self, forKey: .result)
        self.resultComment = try container.decodeIfPresent(String.self, forKey: .resultComment)
        self.action = try container.decodeIfPresent(String.self, forKey: .action)
        self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
        self.properties = try container.decode([AuthenticationMethodProperty].self, forKey: .properties)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(office365AuthenticationServiceIdentifier, forKey: .office365AuthenticationServiceIdentifier)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encode(result, forKey: .result)
        try container.encodeIfPresent(resultComment, forKey: .resultComment)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encode(properties, forKey: .properties)
    }

    internal func encode(_ options: FormatOptions, builder: inout String, lineLength: inout Int) {
        let complete = toString()

        if complete.count + 1 < options.maxLineLength {
            if lineLength + complete.count + 1 > options.maxLineLength {
                builder.append(options.newLine)
                builder.append("\t")
                lineLength = 1
            } else {
                builder.append(" ")
                lineLength += 1
            }

            lineLength += complete.count
            builder.append(complete)
            return
        }

        var tokens: [String] = [" "]

        if let srvid = office365AuthenticationServiceIdentifier {
            tokens.append(srvid)
            tokens.append(";")
            tokens.append(" ")
        }

        if let version {
            let versionText = String(version)
            if method.count + 1 + versionText.count + 1 + result.count < options.maxLineLength {
                tokens.append("\(method)/\(versionText)=\(result)")
            } else if method.count + 1 + versionText.count < options.maxLineLength {
                tokens.append("\(method)/\(versionText)")
                tokens.append("=")
                tokens.append(result)
            } else {
                tokens.append(method)
                tokens.append("/")
                tokens.append(versionText)
                tokens.append("=")
                tokens.append(result)
            }
        } else {
            if method.count + 1 + result.count < options.maxLineLength {
                tokens.append("\(method)=\(result)")
            } else {
                tokens.append(method)
                tokens.append("=")
                tokens.append(result)
            }
        }

        if let comment = resultComment, !comment.isEmpty {
            tokens.append(" ")
            tokens.append("(\(comment))")
        }

        if let reason = reason, !reason.isEmpty {
            let quoted = MimeUtils.quote(reason)
            tokens.append(" ")
            if "reason=".count + quoted.count < options.maxLineLength {
                tokens.append("reason=\(quoted)")
            } else {
                tokens.append("reason=")
                tokens.append(quoted)
            }
        } else if let action = action, !action.isEmpty {
            let quoted = MimeUtils.quote(action)
            tokens.append(" ")
            if "action=".count + quoted.count < options.maxLineLength {
                tokens.append("action=\(quoted)")
            } else {
                tokens.append("action=")
                tokens.append(quoted)
            }
        }

        for property in properties {
            property.appendTokens(options, tokens: &tokens)
        }

        StringBuilderUtils.appendTokens(&builder, options: options, lineLength: &lineLength, tokens: tokens)
    }

    /// Serialize the `AuthenticationMethodResult` to a string.
    ///
    /// Creates a string-representation of the `AuthenticationMethodResult`.
    ///
    /// - Returns: The serialized string.
    public func toString() -> String {
        var builder = ValueStringBuilder(initialCapacity: 128)
        writeTo(&builder)
        return builder.toString()
    }

    internal func writeTo(_ builder: inout ValueStringBuilder) {
        if let srvid = office365AuthenticationServiceIdentifier {
            builder.append(srvid)
            builder.append("; ")
        }

        builder.append(method)

        if let version {
            builder.append("/")
            builder.append(String(version))
        }

        builder.append("=")
        builder.append(result)

        if let comment = resultComment, !comment.isEmpty {
            builder.append(" (")
            builder.append(comment)
            builder.append(")")
        }

        if let reason = reason, !reason.isEmpty {
            builder.append(" reason=")
            builder.append(MimeUtils.quote(reason))
        } else if let action = action, !action.isEmpty {
            builder.append(" action=")
            builder.append(MimeUtils.quote(action))
        }

        for property in properties {
            builder.append(" ")
            property.writeTo(&builder)
        }
    }
}

/// An authentication method property.
///
/// Represents a property associated with an authentication method result.
public struct AuthenticationMethodProperty: Codable, Hashable, Sendable {
    private static let tokenSpecials: Set<UInt32> = Set("()<>@,;:\\\"/[]?=".unicodeScalars.map { $0.value })
    private let quoted: Bool?

    /// The type of the property.
    public let propertyType: String

    /// The property name.
    public let property: String

    /// The property value.
    public let value: String

    internal init(ptype: String, property: String, value: String, quoted: Bool?) {
        self.quoted = quoted
        self.propertyType = ptype
        self.property = property
        self.value = value
    }

    /// Initialize a new instance of `AuthenticationMethodProperty`.
    ///
    /// - Parameters:
    ///   - ptype: The property type.
    ///   - property: The name of the property.
    ///   - value: The value of the property.
    public init(_ ptype: String, _ property: String, _ value: String) {
        self.quoted = nil
        self.propertyType = ptype
        self.property = property
        self.value = value
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case propertyType, property, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.propertyType = try container.decode(String.self, forKey: .propertyType)
        self.property = try container.decode(String.self, forKey: .property)
        self.value = try container.decode(String.self, forKey: .value)
        self.quoted = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(propertyType, forKey: .propertyType)
        try container.encode(property, forKey: .property)
        try container.encode(value, forKey: .value)
    }

    internal func appendTokens(_ options: FormatOptions, tokens: inout [String]) {
        let shouldQuote = quoted ?? value.unicodeScalars.contains { Self.tokenSpecials.contains($0.value) }
        let encodedValue = shouldQuote ? MimeUtils.quote(value) : value

        tokens.append(" ")

        if propertyType.count + 1 + property.count + 1 + encodedValue.count < options.maxLineLength {
            tokens.append("\(propertyType).\(property)=\(encodedValue)")
        } else if propertyType.count + 1 + property.count + 1 < options.maxLineLength {
            tokens.append("\(propertyType).\(property)=")
            tokens.append(encodedValue)
        } else {
            tokens.append(propertyType)
            tokens.append(".")
            tokens.append(property)
            tokens.append("=")
            tokens.append(encodedValue)
        }
    }

    /// Serialize the `AuthenticationMethodProperty` to a string.
    ///
    /// Creates a string-representation of the `AuthenticationMethodProperty`.
    ///
    /// - Returns: The serialized string.
    public func toString() -> String {
        var builder = ValueStringBuilder(initialCapacity: 128)
        writeTo(&builder)
        return builder.toString()
    }

    internal func writeTo(_ builder: inout ValueStringBuilder) {
        let shouldQuote = quoted ?? value.unicodeScalars.contains { Self.tokenSpecials.contains($0.value) }

        builder.append(propertyType)
        builder.append(".")
        builder.append(property)
        builder.append("=")

        if shouldQuote {
            builder.append(MimeUtils.quote(value))
        } else {
            builder.append(value)
        }
    }
}
