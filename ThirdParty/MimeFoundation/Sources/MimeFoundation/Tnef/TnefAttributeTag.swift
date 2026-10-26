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
// TnefAttributeTag.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// The type of a TNEF attribute.
///
/// Internal enum used to categorize TNEF attribute types by their data representation.
enum TnefAttributeType: Int {
    /// Triple value type.
    case triples = 0x00000000
    /// String value type.
    case string  = 0x00010000
    /// Text value type.
    case text    = 0x00020000
    /// Date value type.
    case date    = 0x00030000
    /// Short (16-bit) value type.
    case short   = 0x00040000
    /// Long (32-bit) value type.
    case long    = 0x00050000
    /// Byte value type.
    case byte    = 0x00060000
    /// Word value type.
    case word    = 0x00070000
    /// Double word (32-bit) value type.
    case dword   = 0x00080000
    /// Maximum value type marker.
    case max     = 0x00090000
}

/// A TNEF attribute tag.
///
/// TNEF attribute tags identify the type of attribute stored in a TNEF stream.
/// Each tag combines an attribute type with a unique identifier.
public enum TnefAttributeTag: Int, Sendable {
    /// A Null TNEF attribute.
    ///
    /// Represents an empty or unset attribute.
    case null                    = 0x00000000 // TnefAttributeType.triples | 0x0000

    /// The Owner TNEF attribute.
    ///
    /// Contains information about the owner of the TNEF data.
    case owner                   = 0x00060000 // TnefAttributeType.byte    | 0x0000

    /// The SentFor TNEF attribute.
    ///
    /// Contains information about who the message was sent for.
    case sentFor                 = 0x00060001 // TnefAttributeType.byte    | 0x0001

    /// The Delegate TNEF attribute.
    ///
    /// Contains delegate information for the message.
    case delegate                = 0x00060002 // TnefAttributeType.byte    | 0x0002

    /// The OriginalMessageClass TNEF attribute.
    ///
    /// Contains the original message class of the encapsulated message.
    case originalMessageClass    = 0x00070006 // TnefAttributeType.word    | 0x0006

    /// The DateStart TNEF attribute.
    ///
    /// Contains the start date for a meeting or appointment.
    case dateStart               = 0x00030006 // TnefAttributeType.date    | 0x0006

    /// The DateEnd TNEF attribute.
    ///
    /// Contains the end date for a meeting or appointment.
    case dateEnd                 = 0x00030007 // TnefAttributeType.date    | 0x0007

    /// The AidOwner TNEF attribute.
    ///
    /// Contains the owner's appointment ID.
    case aidOwner                = 0x00050008 // TnefAttributeType.long    | 0x0008

    /// The RequestResponse TNEF attribute.
    ///
    /// Indicates whether a response is requested for a meeting.
    case requestResponse         = 0x00040009 // TnefAttributeType.short   | 0x0009

    /// The From TNEF attribute.
    ///
    /// Contains the sender's address information.
    case from                    = 0x00008000 // TnefAttributeType.triples | 0x8000

    /// The Subject TNEF attribute.
    ///
    /// Contains the subject of the message.
    case subject                 = 0x00018004 // TnefAttributeType.string  | 0x8004

    /// The DateSent TNEF attribute.
    ///
    /// Contains the date and time when the message was sent.
    case dateSent                = 0x00038005 // TnefAttributeType.date    | 0x8005

    /// The DateReceived TNEF attribute.
    ///
    /// Contains the date and time when the message was received.
    case dateReceived            = 0x00038006 // TnefAttributeType.date    | 0x8006

    /// The MessageStatus TNEF attribute.
    ///
    /// Contains status flags for the message.
    case messageStatus           = 0x00068007 // TnefAttributeType.byte    | 0x8007

    /// The MessageClass TNEF attribute.
    ///
    /// Contains the message class (e.g., IPM.Note, IPM.Appointment).
    case messageClass            = 0x00078008 // TnefAttributeType.word    | 0x8008

    /// The MessageId TNEF attribute.
    ///
    /// Contains the unique message identifier.
    case messageId               = 0x00018009 // TnefAttributeType.string  | 0x8009

    /// The ParentId TNEF attribute.
    ///
    /// Contains the identifier of the parent message.
    case parentId                = 0x0001800A // TnefAttributeType.string  | 0x800A

    /// The ConversationId TNEF attribute.
    ///
    /// Contains the conversation thread identifier.
    case conversationId          = 0x0001800B // TnefAttributeType.string  | 0x800B

    /// The Body TNEF attribute.
    ///
    /// Contains the plain text body of the message.
    case body                    = 0x0002800C // TnefAttributeType.text    | 0x800C

    /// The Priority TNEF attribute.
    ///
    /// Contains the message priority level.
    case priority                = 0x0004800D // TnefAttributeType.short   | 0x800D

    /// The AttachData TNEF attribute.
    ///
    /// Contains the binary data of an attachment.
    case attachData              = 0x0006800F // TnefAttributeType.byte    | 0x800F

    /// The AttachTitle TNEF attribute.
    ///
    /// Contains the title or filename of an attachment.
    case attachTitle             = 0x00018010 // TnefAttributeType.string  | 0x8010

    /// The AttachMetaFile TNEF attribute.
    ///
    /// Contains a Windows Metafile representation of the attachment.
    case attachMetaFile          = 0x00068011 // TnefAttributeType.byte    | 0x8011

    /// The AttachCreateDate TNEF attribute.
    ///
    /// Contains the creation date of an attachment.
    case attachCreateDate        = 0x00038012 // TnefAttributeType.date    | 0x8012

    /// The AttachModifyDate TNEF attribute.
    ///
    /// Contains the last modification date of an attachment.
    case attachModifyDate        = 0x00038013 // TnefAttributeType.date    | 0x8013

    /// The DateModified TNEF attribute.
    ///
    /// Contains the date when the message was last modified.
    case dateModified            = 0x00038020 // TnefAttributeType.date    | 0x8020

    /// The AttachTransportFilename TNEF attribute.
    ///
    /// Contains the transport filename of an attachment.
    case attachTransportFilename = 0x00069001 // TnefAttributeType.byte    | 0x9001

    /// The AttachRenderData TNEF attribute.
    ///
    /// Contains rendering information for an attachment, indicating
    /// the start of a new attachment in the TNEF stream.
    case attachRenderData        = 0x00069002 // TnefAttributeType.byte    | 0x9002

    /// The MapiProperties TNEF attribute.
    ///
    /// Contains a collection of MAPI properties for the message.
    case mapiProperties          = 0x00069003 // TnefAttributeType.byte    | 0x9003

    /// The RecipientTable TNEF attribute.
    ///
    /// Contains the recipient table with To, Cc, and Bcc addresses.
    case recipientTable          = 0x00069004 // TnefAttributeType.byte    | 0x9004

    /// The Attachment TNEF attribute.
    ///
    /// Contains MAPI properties for an attachment.
    case attachment              = 0x00069005 // TnefAttributeType.byte    | 0x9005

    /// The TnefVersion TNEF attribute.
    ///
    /// Contains the TNEF format version number.
    case tnefVersion             = 0x00089006 // TnefAttributeType.dword   | 0x9006

    /// The OemCodepage TNEF attribute.
    ///
    /// Contains the OEM codepage used for string encoding.
    case oemCodepage             = 0x00069007 // TnefAttributeType.byte    | 0x9007
}
