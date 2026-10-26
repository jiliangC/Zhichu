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
// TnefPropertyReader.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A TNEF property reader.
///
/// The `TnefPropertyReader` is used to read MAPI properties from a TNEF stream.
/// It provides methods to navigate through properties and read their values in various formats.
public class TnefPropertyReader {
    private var propertyTagValue: TnefPropertyTag = .null
    private unowned let reader: TnefReader
    private var propertyName: TnefNameId = .init()
    private var rawValueOffset: Int = 0
    private var rawValueLength: Int = 0
    private var propertyIndex: Int = 0
    private var propertyCount: Int = 0
    private var valueIndex: Int = 0
    private var valueCount: Int = 0
    private var rowIndex: Int = 0
    private var rowCount: Int = 0

    internal var attachMethod: TnefAttachMethod = .none

    /// Get a value indicating whether the current property is an embedded TNEF message.
    ///
    /// `true` if the current property is an embedded TNEF message; otherwise, `false`.
    public var isEmbeddedMessage: Bool {
        propertyTagValue.id == .attachData && attachMethod == .embeddedMessage
    }

    /// Get a value indicating whether the current property has multiple values.
    ///
    /// `true` if the current property has multiple values; otherwise, `false`.
    public var isMultiValuedProperty: Bool {
        propertyTagValue.isMultiValued
    }

    /// Get a value indicating whether the current property is a named property.
    ///
    /// `true` if the current property is a named property; otherwise, `false`.
    public var isNamedProperty: Bool {
        propertyTagValue.isNamed
    }

    /// Get a value indicating whether the current property contains object values.
    ///
    /// `true` if the current property contains object values; otherwise, `false`.
    public var isObjectProperty: Bool {
        propertyTagValue.type == .object
    }

    /// Get the number of properties available.
    ///
    /// The total number of properties available to be read in the current attribute or row.
    public var propertyCountAvailable: Int {
        propertyCount
    }

    /// Get the property name identifier.
    ///
    /// For named properties, this returns the identifier used to look up the property name.
    public var propertyNameId: TnefNameId {
        propertyName
    }

    /// Get the property tag.
    ///
    /// The property tag contains both the property identifier and the property type.
    public var propertyTag: TnefPropertyTag {
        propertyTagValue
    }

    /// Get the length of the raw value.
    ///
    /// The number of bytes in the current property's raw value.
    public var rawValueLengthAvailable: Int {
        rawValueLength
    }

    /// Get the raw value stream offset.
    ///
    /// The byte offset within the TNEF stream where the current property's raw value begins.
    public var rawValueStreamOffset: Int {
        rawValueOffset
    }

    /// Get the number of table rows available.
    ///
    /// For recipient tables, this returns the number of rows available to be read.
    public var rowCountAvailable: Int {
        rowCount
    }

    /// Get the number of values available.
    ///
    /// For multi-valued properties, this returns the number of values in the current property.
    public var valueCountAvailable: Int {
        valueCount
    }

    internal init(reader: TnefReader) {
        self.reader = reader
    }

    /// Get the embedded TNEF message reader.
    ///
    /// Gets a new `TnefReader` for reading the embedded TNEF message.
    ///
    /// - Returns: A new `TnefReader` for the embedded message.
    /// - Throws: `StreamError.notSupported` if the current property is not an embedded message.
    public func getEmbeddedMessageReader() throws -> TnefReader {
        guard isEmbeddedMessage else {
            throw StreamError.notSupported
        }

        let stream = getRawValueReadStream()
        var guid = [UInt8](repeating: 0, count: 16)
        var offset = 0
        while offset < 16 {
            let n = try stream.read(&guid, offset: offset, count: 16 - offset)
            if n <= 0 { break }
            offset += n
        }

        return TnefReader(inputStream: stream, defaultMessageCodepage: reader.messageCodepage, complianceMode: reader.complianceMode)
    }

    /// Get the raw value of the attribute or property as a stream.
    ///
    /// Gets a stream that can be used to read the raw value data.
    ///
    /// - Returns: A `MimeStream` for reading the raw value.
    public func getRawValueReadStream() -> MimeStream {
        let startOffset = rawValueOffset
        var length = rawValueLength

        if propertyCount > 0 && reader.streamOffset == rawValueOffset {
            switch propertyTagValue.type {
            case .unicode, .string8, .binary, .object:
                if let n = try? reader.readInt32(), n >= 0 && Int(n) + 4 < length {
                    length = Int(n) + 4
                }
            default:
                break
            }
        }

        let valueEndOffset = startOffset + rawValueLength
        let dataEndOffset = startOffset + length
        let stream = TnefReaderStream(reader: reader, dataEndOffset: dataEndOffset, valueEndOffset: valueEndOffset)
        
        valueIndex += 1
        return stream
    }

    private func checkRawValueLength() -> Bool {
        let attrEndOffset = reader.attributeRawValueStreamOffset + reader.attributeRawValueLength
        let valueEndOffset = rawValueOffset + rawValueLength

        if valueEndOffset > attrEndOffset {
            reader.setComplianceError(.invalidAttributeValue)
            return false
        }

        return true
    }

    private func readBytes(_ count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            let n = reader.readAttributeRawValue(&bytes, offset: offset, count: count - offset)
            if n <= 0 { break }
            offset += n
        }
        return bytes
    }

    private func readByteArray() throws -> [UInt8] {
        let length = Int(try reader.readInt32())
        let bytes = try readBytes(length)

        if (length % 4) != 0 {
            let padding = 4 - (length % 4)
            _ = try reader.skip(padding)
        }

        return bytes
    }

    private func readUnicodeString() throws -> String {
        let bytes = try readByteArray()
        var length = bytes.count
        
        length &= ~1
        while length > 1 && bytes[length - 1] == 0 && bytes[length - 2] == 0 {
            length -= 2
        }
        
        if length < 2 {
            return ""
        }
        
        return String(data: Data(bytes[0..<length]), encoding: .utf16LittleEndian) ?? ""
    }

    private func getMessageEncoding() -> String.Encoding {
        let codepage = reader.messageCodepage
        return CharsetUtils.getEncoding(codepage: codepage) ?? .isoLatin1
    }

    private func decodeAnsiString(_ bytes: [UInt8]) -> String {
        var length = bytes.count
        while length > 0 && bytes[length - 1] == 0 {
            length -= 1
        }
        if length == 0 {
            return ""
        }
        let encoding = getMessageEncoding()
        return String(data: Data(bytes[0..<length]), encoding: encoding) ?? 
               String(data: Data(bytes[0..<length]), encoding: .isoLatin1) ?? ""
    }

    private func readString() throws -> String {
        let bytes = try readByteArray()
        return decodeAnsiString(bytes)
    }

    private func readAttrBytes() throws -> [UInt8] {
        try readBytes(rawValueLength)
    }

    private func readAttrString() throws -> String {
        let bytes = try readBytes(rawValueLength)
        return decodeAnsiString(bytes)
    }

    private func readAttrDateTime() throws -> DateTimeOffset {
        let year = Int(try reader.readInt16())
        let month = Int(try reader.readInt16())
        let day = Int(try reader.readInt16())
        let hour = Int(try reader.readInt16())
        let minute = Int(try reader.readInt16())
        let second = Int(try reader.readInt16())
        _ = try reader.readInt16() // dow

        if let date = DateTimeOffset(year: year, month: month, day: day, hour: hour, minute: minute, second: second, offsetMinutes: 0) {
            return date
        } else {
            reader.setComplianceError(.invalidDate)
            return DateTimeOffset(date: Date(timeIntervalSince1970: 0), offsetMinutes: 0)
        }
    }

    private func loadPropertyName() throws {
        let guidBytes = try readBytes(16)
        // Construct UUID with proper format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
        let guidString = String(format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                                guidBytes[0], guidBytes[1], guidBytes[2], guidBytes[3],
                                guidBytes[4], guidBytes[5],
                                guidBytes[6], guidBytes[7],
                                guidBytes[8], guidBytes[9],
                                guidBytes[10], guidBytes[11], guidBytes[12], guidBytes[13], guidBytes[14], guidBytes[15])
        let guid = UUID(uuidString: guidString) ?? UUID()
        let kindVal = try reader.readInt32()
        let kind = TnefNameIdKind(rawValue: Int(kindVal)) ?? .id

        if kind == .name {
            let name = try readUnicodeString()
            propertyName = TnefNameId(propertySetGuid: guid, name: name)
        } else {
            let id = try reader.readInt32()
            propertyName = TnefNameId(propertySetGuid: guid, id: id)
        }
    }

    /// Advance to the next MAPI property.
    ///
    /// Advances to the next MAPI property in the current attribute or row.
    ///
    /// - Returns: `true` if there is another property available to be read; otherwise, `false`.
    /// - Throws: ``TnefException`` if the TNEF data is corrupt or invalid.
    public func readNextProperty() throws -> Bool {
        while try readNextValue() {}

        if propertyIndex >= propertyCount {
            return false
        }

        do {
            let typeVal = try reader.readInt16()
            let idVal = try reader.readInt16()
            propertyTagValue = TnefPropertyTag(TnefPropertyId(rawValue: idVal), TnefPropertyType(rawValue: typeVal) ?? .unspecified)

            if propertyTagValue.isNamed {
                try loadPropertyName()
            }

            try loadValueCount()
            propertyIndex += 1

            guard let length = getPropertyValueLength() else {
                return false
            }
            rawValueLength = length

            rawValueOffset = reader.streamOffset

            if propertyTagValue.id == .attachMethod {
                attachMethod = TnefAttachMethod(rawValue: Int(try reader.peekInt32())) ?? .none
            }
        } catch {
            return false
        }

        return checkRawValueLength()
    }

    /// Advance to the next table row of properties.
    ///
    /// Advances to the next table row of properties in a recipient table.
    ///
    /// - Returns: `true` if there is another row available to be read; otherwise, `false`.
    /// - Throws: ``TnefException`` if the TNEF data is corrupt or invalid.
    public func readNextRow() throws -> Bool {
        while try readNextProperty() {}

        if rowIndex >= rowCount {
            return false
        }

        try loadPropertyCount()
        rowIndex += 1
        return true
    }

    /// Advance to the next value in the TNEF stream.
    ///
    /// Advances to the next value in a multi-valued property.
    ///
    /// - Returns: `true` if there is another value available to be read; otherwise, `false`.
    /// - Throws: ``TnefException`` if the TNEF data is corrupt or invalid.
    public func readNextValue() throws -> Bool {
        if valueIndex >= valueCount || propertyCount == 0 {
            return false
        }

        let offset = rawValueOffset + rawValueLength
        if reader.streamOffset < offset, try !reader.skip(offset - reader.streamOffset) {
            return false
        }

        guard let length = getPropertyValueLength() else {
            return false
        }
        rawValueLength = length

        rawValueOffset = reader.streamOffset
        valueIndex += 1
        return true
    }

    private func loadPropertyCount() throws {
        propertyCount = Int(try reader.readInt32())
        if propertyCount < 0 {
            reader.setComplianceError(.invalidPropertyLength)
            propertyCount = 0
        }
        propertyIndex = 0
        valueCount = 0
        valueIndex = 0
    }

    private func loadValueCount() throws {
        if propertyTagValue.isMultiValued {
            valueCount = Int(try reader.readInt32())
        } else {
            switch propertyTagValue.type {
            case .unicode, .string8, .binary, .object:
                valueCount = Int(try reader.readInt32())
            default:
                valueCount = 1
            }
        }
        valueIndex = 0
    }

    private func loadRowCount() throws {
        rowCount = Int(try reader.readInt32())
        if rowCount < 0 {
            reader.setComplianceError(.invalidRowCount)
            rowCount = 0
        }
        propertyCount = 0
        propertyIndex = 0
        valueCount = 0
        valueIndex = 0
        rowIndex = 0
    }

    internal func load() throws {
        propertyTagValue = .null
        rawValueOffset = 0
        rawValueLength = 0
        propertyCount = 0
        propertyIndex = 0
        valueCount = 0
        valueIndex = 0
        rowCount = 0
        rowIndex = 0

        switch reader.attributeTag {
        case .mapiProperties, .attachment:
            try loadPropertyCount()
        case .recipientTable:
            try loadRowCount()
        case .null, .owner, .sentFor, .delegate, .originalMessageClass, .dateStart, .dateEnd,
             .aidOwner, .requestResponse, .from, .subject, .dateSent, .dateReceived,
             .messageStatus, .messageClass, .messageId, .parentId, .conversationId,
             .body, .priority, .attachData, .attachTitle, .attachMetaFile, .attachCreateDate,
             .attachModifyDate, .dateModified, .attachTransportFilename, .attachRenderData,
             .tnefVersion, .oemCodepage:
            rawValueLength = reader.attributeRawValueLength
            rawValueOffset = reader.streamOffset
            valueCount = 1
        }
    }

    private func getPropertyValueLength() -> Int? {
        switch propertyTagValue.type {
        case .unspecified, .null:
            return 0
        case .boolean, .error, .long, .r4, .i2:
            return 4
        case .currency, .double, .i8, .appTime, .sysTime:
            return 8
        case .classId:
            return 16
        case .unicode, .string8, .binary, .object:
            if let val = try? reader.peekInt32() {
                return 4 + ((Int(val) + 3) & ~3)
            } else {
                return 4
            }
        default:
            reader.setComplianceError(.unsupportedPropertyType)
            return nil
        }
    }

    /// Read the value as a boolean.
    ///
    /// Reads any integer-based attribute or property value as a boolean.
    ///
    /// - Returns: The value as a boolean.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as a boolean.
    public func readValueAsBoolean() throws -> Bool {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var value: Bool
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .boolean:
                value = (try reader.readInt32() & 0xFF) != 0
            case .i2:
                value = (try reader.readInt32() & 0xFFFF) != 0
            case .error, .long:
                value = try reader.readInt32() != 0
            case .currency, .i8:
                value = try reader.readInt64() != 0
            default:
                throw StreamError.notSupported
            }
        } else {
            switch reader.attributeType {
            case 0x00040000: // Short
                value = try reader.readInt16() != 0
            case 0x00050000: // Long
                value = try reader.readInt32() != 0
            case 0x00070000: // Word
                value = try reader.readInt16() != 0
            case 0x00080000: // DWord
                value = try reader.readInt32() != 0
            case 0x00060000: // Byte
                value = try reader.readByte() != 0
            default:
                throw StreamError.notSupported
            }
        }

        valueIndex += 1
        return value
    }

    /// Read the value as a 16-bit integer.
    ///
    /// Reads any integer-based attribute or property value as a 16-bit integer.
    ///
    /// - Returns: The value as a 16-bit integer.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as an integer.
    public func readValueAsInt16() throws -> Int16 {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var value: Int16
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .boolean:
                value = Int16(try reader.readInt32() & 0xFF)
            case .i2:
                value = Int16(try reader.readInt32() & 0xFFFF)
            case .error, .long:
                value = Int16(truncatingIfNeeded: try reader.readInt32())
            case .currency, .i8:
                value = Int16(truncatingIfNeeded: try reader.readInt64())
            case .double:
                value = Int16(try reader.readDouble())
            case .r4:
                value = Int16(try reader.readSingle())
            default:
                throw StreamError.notSupported
            }
        } else {
            switch reader.attributeType {
            case 0x00040000, 0x00070000: // Short, Word
                value = try reader.readInt16()
            case 0x00050000, 0x00080000: // Long, DWord
                value = Int16(truncatingIfNeeded: try reader.readInt32())
            case 0x00060000: // Byte
                value = Int16(try reader.readByte())
            default:
                throw StreamError.notSupported
            }
        }

        valueIndex += 1
        return value
    }

    /// Read the value as a 32-bit integer.
    ///
    /// Reads any integer-based attribute or property value as a 32-bit integer.
    ///
    /// - Returns: The value as a 32-bit integer.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as an integer.
    public func readValueAsInt32() throws -> Int32 {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var value: Int32
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .boolean:
                value = try reader.readInt32() & 0xFF
            case .i2:
                value = try reader.readInt32() & 0xFFFF
            case .error, .long:
                value = try reader.readInt32()
            case .currency, .i8:
                value = Int32(truncatingIfNeeded: try reader.readInt64())
            case .double:
                value = Int32(try reader.readDouble())
            case .r4:
                value = Int32(try reader.readSingle())
            default:
                throw StreamError.notSupported
            }
        } else {
            switch reader.attributeType {
            case 0x00040000, 0x00070000: // Short, Word
                value = Int32(try reader.readInt16())
            case 0x00050000, 0x00080000: // Long, DWord
                value = try reader.readInt32()
            case 0x00060000: // Byte
                value = Int32(try reader.readByte())
            default:
                throw StreamError.notSupported
            }
        }

        valueIndex += 1
        return value
    }

    /// Read the value as a 64-bit integer.
    ///
    /// Reads any integer-based attribute or property value as a 64-bit integer.
    ///
    /// - Returns: The value as a 64-bit integer.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as an integer.
    public func readValueAsInt64() throws -> Int64 {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var value: Int64
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .boolean:
                value = Int64(try reader.readInt32() & 0xFF)
            case .i2:
                value = Int64(try reader.readInt32() & 0xFFFF)
            case .error, .long:
                value = Int64(try reader.readInt32())
            case .currency, .i8:
                value = try reader.readInt64()
            case .double:
                value = Int64(try reader.readDouble())
            case .r4:
                value = Int64(try reader.readSingle())
            default:
                throw StreamError.notSupported
            }
        } else {
            switch reader.attributeType {
            case 0x00040000, 0x00070000: // Short, Word
                value = Int64(try reader.readInt16())
            case 0x00050000, 0x00080000: // Long, DWord
                value = Int64(try reader.readInt32())
            case 0x00060000: // Byte
                value = Int64(try reader.readByte())
            default:
                throw StreamError.notSupported
            }
        }

        valueIndex += 1
        return value
    }

    /// Read the value as a string.
    ///
    /// Reads any string or binary blob values as a string.
    ///
    /// - Returns: The value as a string.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as a string.
    public func readValueAsString() throws -> String {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var value: String
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .unicode: value = try readUnicodeString()
            case .string8, .binary: value = try readString()
            default:
                throw StreamError.notSupported
            }
        } else {
            switch reader.attributeType {
            case 0x00010000, 0x00020000: // String, Text
                value = try readAttrString()
            case 0x00060000: // Byte
                value = try readAttrString()
            default:
                throw StreamError.notSupported
            }
        }

        valueIndex += 1
        return value
    }

    /// Read the value as a sequence of bytes.
    ///
    /// Reads any string, binary blob, Class ID, or Object attribute or property value as a byte array.
    ///
    /// - Returns: The value as a byte array.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as bytes.
    public func readValueAsBytes() throws -> [UInt8] {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var bytes: [UInt8]
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .unicode, .string8, .binary, .object:
                bytes = try readByteArray()
            case .classId:
                bytes = try readBytes(16)
            default:
                throw StreamError.notSupported
            }
        } else {
            switch reader.attributeType {
            case 0x00000000, 0x00010000, 0x00020000, 0x00060000: // Triples, String, Text, Byte
                bytes = try readAttrBytes()
            default:
                throw StreamError.notSupported
            }
        }

        valueIndex += 1
        return bytes
    }

    /// Read the value as a date and time.
    ///
    /// Reads any date and time attribute or property value as a `DateTimeOffset`.
    ///
    /// - Returns: The value as a date and time.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as a date and time.
    public func readValueAsDateTime() throws -> DateTimeOffset {
        if valueIndex >= valueCount || reader.streamOffset > rawValueOffset {
            throw StreamError.notSupported
        }

        var value: DateTimeOffset
        if propertyCount > 0 {
            switch propertyTagValue.type {
            case .appTime:
                let appTime = try reader.readDouble()
                value = DateTimeOffset(date: Date(timeIntervalSince1970: (appTime - 25569.0) * 86400.0), offsetMinutes: 0) // OADate to Unix
            case .sysTime:
                let fileTime = try reader.readInt64()
                value = DateTimeOffset(date: Date(timeIntervalSince1970: Double(fileTime) / 10_000_000.0 - 11_644_473_600.0), offsetMinutes: 0) // FileTime to Unix
            default:
                throw StreamError.notSupported
            }
        } else if reader.attributeType == 0x00030000 { // Date
            value = try readAttrDateTime()
        } else {
            throw StreamError.notSupported
        }

        valueIndex += 1
        return value
    }

    /// Read the value as a URI.
    ///
    /// Reads any string or binary blob values as a URL.
    ///
    /// - Returns: The value as a URL, or `nil` if the string is not a valid URL.
    /// - Throws: `StreamError.notSupported` if there are no more values to read or the value cannot be read as a string.
    public func readValueAsUri() throws -> URL? {
        let value = try readValueAsString()
        return URL(string: value)
    }
}
