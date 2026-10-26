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
// TnefNameId.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A TNEF name identifier.
///
/// Named properties in MAPI are identified by either an integer identifier or a string name,
/// combined with a property set GUID. This struct represents such a named property identifier.
public struct TnefNameId: Hashable, Sendable {
    /// The kind of TNEF name identifier.
    ///
    /// Indicates whether this named property is identified by an integer (``TnefNameIdKind/id``)
    /// or a string (``TnefNameIdKind/name``).
    public let kind: TnefNameIdKind

    /// The name, if available.
    ///
    /// If the ``kind`` is ``TnefNameIdKind/name``, then this property will contain the
    /// string name of the property. Otherwise, this property will be `nil`.
    public let name: String?

    /// The property set GUID.
    ///
    /// The GUID identifies the property set that this named property belongs to.
    /// Common property sets include PS_PUBLIC_STRINGS, PS_MAPI, and PS_INTERNET_HEADERS.
    public let guid: UUID

    /// The identifier, if available.
    ///
    /// If the ``kind`` is ``TnefNameIdKind/id``, then this property will contain the
    /// integer identifier. Otherwise, this property will be 0.
    public let id: Int32

    /// Initialize a new instance of the ``TnefNameId`` struct with an integer identifier.
    ///
    /// Creates a new ``TnefNameId`` with the specified integer identifier.
    ///
    /// - Parameters:
    ///   - propertySetGuid: The property set GUID.
    ///   - id: The integer identifier.
    public init(propertySetGuid: UUID, id: Int32) {
        self.kind = .id
        self.guid = propertySetGuid
        self.id = id
        self.name = nil
    }

    /// Initialize a new instance of the ``TnefNameId`` struct with a string identifier.
    ///
    /// Creates a new ``TnefNameId`` with the specified string identifier.
    ///
    /// - Parameters:
    ///   - propertySetGuid: The property set GUID.
    ///   - name: The string name.
    public init(propertySetGuid: UUID, name: String) {
        self.kind = .name
        self.guid = propertySetGuid
        self.name = name
        self.id = 0
    }

    /// Initialize a new default instance of the ``TnefNameId`` struct.
    ///
    /// Creates a new ``TnefNameId`` with a nil GUID and zero identifier.
    public init() {
        self.kind = .id
        self.guid = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        self.id = 0
        self.name = nil
    }
}
