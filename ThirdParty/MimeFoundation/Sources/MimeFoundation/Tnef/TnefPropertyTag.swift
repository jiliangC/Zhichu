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
// TnefPropertyTag.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A TNEF property tag.
///
/// A TNEF property tag combines a property identifier (``TnefPropertyId``) with a
/// property type (``TnefPropertyType``) to uniquely identify a MAPI property.
/// Property tags are used to read and write MAPI properties in TNEF streams.
public struct TnefPropertyTag: Hashable, Sendable {
    /// The property identifier.
    ///
    /// The identifier specifies which property this tag represents (e.g., subject,
    /// sender, body text). See ``TnefPropertyId`` for a list of known identifiers.
    public let id: TnefPropertyId

    /// The property type.
    ///
    /// The type specifies the data type of the property value (e.g., string,
    /// integer, binary). See ``TnefPropertyType`` for a list of supported types.
    public let type: TnefPropertyType

    /// A value indicating whether the property contains multiple values.
    ///
    /// When `true`, the property value is an array of values of the specified type.
    /// When `false`, the property contains a single value.
    public let isMultiValued: Bool

    /// Initialize a new instance of the ``TnefPropertyTag`` struct.
    ///
    /// Creates a property tag with the specified identifier and type.
    ///
    /// - Parameters:
    ///   - id: The property identifier.
    ///   - type: The property type.
    ///   - isMultiValued: A value indicating whether the property contains multiple values.
    public init(_ id: TnefPropertyId, _ type: TnefPropertyType, _ isMultiValued: Bool = false) {
        self.id = id
        self.type = type
        self.isMultiValued = isMultiValued
    }

    /// Initialize a new instance of the ``TnefPropertyTag`` struct from a raw value.
    ///
    /// Decodes a property tag from its 32-bit raw representation as stored in a TNEF stream.
    /// The low 16 bits contain the property type, and the high 16 bits contain the
    /// property identifier.
    ///
    /// - Parameter rawValue: The raw 32-bit property tag value.
    public init(rawValue: Int32) {
        let typeValue = Int16(truncatingIfNeeded: rawValue & 0xFFFF)
        let idValue = Int16(truncatingIfNeeded: (rawValue >> 16) & 0xFFFF)

        self.isMultiValued = (typeValue & 0x1000) != 0
        self.type = TnefPropertyType(rawValue: typeValue & ~0x1000) ?? .unspecified
        self.id = TnefPropertyId(rawValue: idValue)
    }

    /// A value indicating whether the property is a named property.
    ///
    /// Named properties have identifiers in the range 0x8000 to 0xFFFE.
    /// These properties are defined by applications rather than by MAPI itself.
    public var isNamed: Bool {
        // Named properties have IDs in the range 0x8000 to 0xFFFE
        (0x8000...0xFFFE).contains(UInt16(bitPattern: id.rawValue))
    }

    /// The TNEF property type for the value.
    ///
    /// This property returns the same value as ``type`` and exists for
    /// compatibility with the MimeKit API.
    public var valueTnefType: TnefPropertyType {
        type
    }

    /// The raw 32-bit representation of the property tag.
    ///
    /// The raw value encodes the property type in the low 16 bits and the
    /// property identifier in the high 16 bits. The multi-valued flag is
    /// encoded in bit 12 of the type field.
    public var rawValue: Int32 {
        let typeValue = Int32(type.rawValue) | (isMultiValued ? 0x1000 : 0)
        return (Int32(id.rawValue) << 16) | typeValue
    }

    /// A null property tag.
    ///
    /// Represents an empty or unset property tag.
    public static let null = TnefPropertyTag(.null, .null)
}
