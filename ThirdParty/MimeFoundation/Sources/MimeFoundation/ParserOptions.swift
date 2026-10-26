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
// ParserOptions.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Parser options as used by ``MimeParser`` as well as various parse methods in MimeFoundation.
///
/// `ParserOptions` allows you to change and/or override default parsing options used by methods such
/// as ``MimeMessage/load(_:_:)`` and others.
public struct ParserOptions: Sendable {
    /// The default parser options.
    ///
    /// If a `ParserOptions` is not supplied to ``MimeParser`` or other parse methods
    /// throughout MimeFoundation, `ParserOptions.default` will be used.
    public static var `default`: ParserOptions { ParserOptions() }

    /// Errors that can occur when registering MIME types.
    public enum Error: Swift.Error, Equatable {
        /// The specified MIME type string is empty.
        case emptyMimeType

        /// The specified MIME type string is not a valid MIME type.
        case invalidMimeType
    }

    /// A factory closure for creating custom ``MimeEntity`` instances.
    ///
    /// The factory receives a ``ContentType`` and should return an appropriate
    /// ``MimeEntity`` subclass instance for that content type.
    public typealias MimeEntityFactory = @Sendable (ContentType) -> MimeEntity

    /// The compliance mode that should be used when parsing RFC 822 addresses.
    ///
    /// In general, you'll probably want this value to be ``RfcComplianceMode/loose``
    /// (the default) as it allows maximum interoperability with existing (broken) mail clients
    /// and other mail software such as sloppily written scripts.
    ///
    /// Even in ``RfcComplianceMode/strict`` mode, the address parser is fairly liberal
    /// in what it accepts. Setting it to ``RfcComplianceMode/loose`` just makes it try
    /// harder to deal with garbage input.
    public var addressParserComplianceMode: RfcComplianceMode

    /// The compliance mode that should be used when parsing Content-Type and Content-Disposition parameters.
    ///
    /// In general, you'll probably want this value to be ``RfcComplianceMode/loose``
    /// (the default) as it allows maximum interoperability with existing (broken) mail clients
    /// and other mail software such as sloppily written scripts.
    ///
    /// Even in ``RfcComplianceMode/strict`` mode, the parameter parser is fairly liberal
    /// in what it accepts. Setting it to ``RfcComplianceMode/loose`` just makes it try
    /// harder to deal with garbage input.
    public var parameterComplianceMode: RfcComplianceMode

    /// The compliance mode that should be used when decoding RFC 2047 encoded words.
    ///
    /// In general, you'll probably want this value to be ``RfcComplianceMode/loose``
    /// (the default) as it allows maximum interoperability with existing (broken) mail clients
    /// and other mail software such as sloppily written scripts.
    public var rfc2047ComplianceMode: RfcComplianceMode

    /// Whether the RFC 822 address parser should ignore unquoted commas in address names.
    ///
    /// In general, you'll probably want this value to be `true` (the default) as it allows
    /// maximum interoperability with existing (broken) mail clients and other mail software such as
    /// sloppily written scripts that do not properly quote the name when it contains a comma.
    public var allowUnquotedCommasInAddresses: Bool

    /// Whether the RFC 822 address parser should allow addresses without a domain.
    ///
    /// In general, you'll probably want this value to be `true` (the default) as it allows
    /// maximum interoperability with older email messages that may contain local UNIX addresses.
    ///
    /// This option exists in order to allow parsing of mailbox addresses that do not have an
    /// @domain component. These types of addresses are rare and were typically only used when sending
    /// mail to other users on the same UNIX system.
    public var allowAddressesWithoutDomain: Bool

    /// The maximum address group depth the parser should accept.
    ///
    /// This option exists in order to define the maximum recursive depth of an RFC 822 group address
    /// that the parser should accept before bailing out with the assumption that the address is maliciously
    /// formed. If the value is set too large, then it is possible that a maliciously formed set of
    /// recursive group addresses could cause a stack overflow.
    public var maxAddressGroupDepth: Int

    /// The maximum MIME nesting depth the parser should accept.
    ///
    /// This option exists in order to define the maximum recursive depth of MIME parts that the parser
    /// should accept before treating further nesting as a leaf-node MIME part and not recursing any further.
    /// If the value is set too large, then it is possible that a maliciously formed set of deeply nested
    /// multipart MIME parts could cause a stack overflow.
    public var maxMimeDepth: Int

    /// Whether the Content-Length value should be respected when parsing mbox streams.
    ///
    /// For more details about why this may be useful, you can find more information
    /// at [http://www.jwz.org/doc/content-length.html](http://www.jwz.org/doc/content-length.html).
    public var respectContentLength: Bool

    /// The charset encoding to use as a fallback for 8-bit headers.
    ///
    /// This charset encoding is used as a fallback when decoding 8-bit text into Unicode.
    /// The first charset encoding attempted is UTF-8, followed by this charset encoding,
    /// before finally falling back to ISO-8859-1.
    public var charsetEncoding: String.Encoding

    /// Registered MIME type factories for creating custom entity types.
    private var mimeTypeFactories: [String: MimeEntityFactory]

    /// Initializes a new instance of `ParserOptions` with default values.
    ///
    /// By default, new instances of `ParserOptions` enable RFC 2047 work-arounds
    /// (which are needed for maximum interoperability with mail software used in the wild)
    /// and do not respect the Content-Length header value.
    public init() {
        self.addressParserComplianceMode = .loose
        self.parameterComplianceMode = .loose
        self.rfc2047ComplianceMode = .loose
        self.allowUnquotedCommasInAddresses = true
        self.allowAddressesWithoutDomain = true
        self.maxAddressGroupDepth = 3
        self.maxMimeDepth = 1024
        self.respectContentLength = false
        self.charsetEncoding = CharsetUtils.utf8
        self.mimeTypeFactories = [:]
    }

    /// Creates a copy of this `ParserOptions` instance.
    ///
    /// Clones a set of options, allowing you to change a specific option
    /// without requiring you to change the original.
    ///
    /// - Returns: An identical copy of the current instance.
    public func copy() -> ParserOptions {
        self
    }

    /// Registers a ``MimeEntity`` factory for the specified MIME type.
    ///
    /// Use this method to register custom entity types that should be created
    /// when parsing content of a specific MIME type.
    ///
    /// - Parameters:
    ///   - mimeType: The MIME type (e.g., "application/custom").
    ///   - factory: A factory closure that creates the custom entity.
    /// - Throws: ``Error/emptyMimeType`` if the MIME type is empty.
    /// - Throws: ``Error/invalidMimeType`` if the MIME type is not valid.
    public mutating func registerMimeType(_ mimeType: String, factory: @escaping MimeEntityFactory) throws {
        let trimmed = mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw Error.emptyMimeType
        }
        guard let contentType = try? ContentType(parsing: trimmed) else {
            throw Error.invalidMimeType
        }
        let key = contentType.mimeType.lowercased()
        mimeTypeFactories[key] = factory
    }

    /// Creates an entity for the given content type using a registered factory.
    ///
    /// - Parameter contentType: The content type to create an entity for.
    /// - Returns: The created entity, or `nil` if no factory is registered for the content type.
    internal func makeEntity(for contentType: ContentType) -> MimeEntity? {
        let key = contentType.mimeType.lowercased()
        return mimeTypeFactories[key]?(contentType)
    }
}
