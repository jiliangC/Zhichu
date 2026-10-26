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
// TnefPropertyType.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// The type of value that a TNEF property contains.
///
/// TNEF properties use MAPI property types to specify the format of their values.
/// This enumeration defines the supported property types.
public enum TnefPropertyType: Int16, Sendable {
    /// The type of the property is unspecified.
    ///
    /// Used when the property type is unknown or not yet determined.
    case unspecified = 0

    /// The property has a null value.
    ///
    /// Indicates that the property has no value.
    case null        = 1

    /// The property has a signed 16-bit value.
    ///
    /// Also known as PT_I2 or PT_SHORT in MAPI terminology.
    case i2          = 2

    /// The property has a signed 32-bit value.
    ///
    /// Also known as PT_I4 or PT_LONG in MAPI terminology.
    case long        = 3

    /// The property has a 32-bit floating point value.
    ///
    /// Also known as PT_R4 or PT_FLOAT in MAPI terminology.
    case r4          = 4

    /// The property has a 64-bit floating point value.
    ///
    /// Also known as PT_R8 or PT_DOUBLE in MAPI terminology.
    case double      = 5

    /// The property has a 64-bit integer value representing 1/10000th of a monetary unit.
    ///
    /// Also known as PT_CURRENCY in MAPI terminology. The value represents
    /// currency in 1/100th of a cent (i.e., 1/10000th of the base monetary unit).
    case currency    = 6

    /// The property has a 64-bit integer value specifying the number of 100ns periods since Jan 1, 1601.
    ///
    /// Also known as PT_APPTIME in MAPI terminology. Used for application-specific
    /// time values.
    case appTime     = 7

    /// The property has a 32-bit error value.
    ///
    /// Also known as PT_ERROR in MAPI terminology. Contains an HRESULT error code.
    case error       = 10

    /// The property has a boolean value.
    ///
    /// Also known as PT_BOOLEAN in MAPI terminology. Non-zero values are `true`.
    case boolean     = 11

    /// The property has an embedded object value.
    ///
    /// Also known as PT_OBJECT in MAPI terminology. Contains an embedded
    /// MAPI object or OLE object.
    case object      = 13

    /// The property has a signed 64-bit value.
    ///
    /// Also known as PT_I8 or PT_LONGLONG in MAPI terminology.
    case i8          = 20

    /// The property has a null-terminated 8-bit character string value.
    ///
    /// Also known as PT_STRING8 in MAPI terminology. The string is encoded
    /// using the code page specified in the TNEF stream.
    case string8     = 30

    /// The property has a null-terminated unicode character string value.
    ///
    /// Also known as PT_UNICODE in MAPI terminology. The string is encoded
    /// as UTF-16LE.
    case unicode     = 31

    /// The property has a 64-bit integer value specifying the number of 100ns periods since Jan 1, 1601.
    ///
    /// Also known as PT_SYSTIME in MAPI terminology. Used for system time values
    /// such as creation time, modification time, etc.
    case sysTime     = 64

    /// The property has an OLE GUID value.
    ///
    /// Also known as PT_CLSID in MAPI terminology. Contains a 16-byte GUID.
    case classId     = 72

    /// The property has a binary blob value.
    ///
    /// Also known as PT_BINARY in MAPI terminology. Contains arbitrary binary data.
    case binary      = 258

    /// A flag indicating that the property contains multiple values.
    ///
    /// This flag can be combined with other property types using bitwise OR
    /// to indicate that the property contains an array of values.
    case multiValued = 4096
}
