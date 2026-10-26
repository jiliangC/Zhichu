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
// HeaderId.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// An enumeration of common header fields.
///
/// Comparing enum values is not only faster, but less error-prone than comparing strings.
/// This enumeration provides identifiers for the most commonly used MIME and email headers.
///
/// ## Overview
///
/// Use ``HeaderId`` values when working with ``Header`` objects to avoid string comparison
/// overhead and reduce the risk of typos in header field names.
///
/// ## Example
///
/// ```swift
/// let header = Header(.subject, value: "Hello World")
/// switch header.id {
/// case .subject:
///     print("This is a Subject header")
/// case .from:
///     print("This is a From header")
/// default:
///     print("This is some other header")
/// }
/// ```
public enum HeaderId: Int, Sendable, CaseIterable {
    /// An unknown or unrecognized header field.
    case unknown
    /// The Ad-Hoc header field.
    case adHoc
    /// The Bcc header field.
    case bcc
    /// The Cc header field.
    case cc
    /// The From header field.
    case from
    /// The To header field.
    case to
    /// The Reply-To header field.
    case replyTo
    /// The Sender header field.
    case sender
    /// The Resent-Bcc header field.
    case resentBcc
    /// The Resent-Cc header field.
    case resentCc
    /// The Resent-From header field.
    case resentFrom
    /// The Resent-To header field.
    case resentTo
    /// The Resent-Reply-To header field.
    case resentReplyTo
    /// The Resent-Sender header field.
    case resentSender
    /// The Resent-Date header field.
    case resentDate
    /// The Resent-Message-Id header field.
    case resentMessageId
    /// The Original-Message-Id header field.
    case originalMessageId
    /// The Date header field.
    case date
    /// The Subject header field.
    case subject
    /// The Message-Id header field.
    case messageId
    /// The In-Reply-To header field.
    case inReplyTo
    /// The References header field.
    case references
    /// The MIME-Version header field.
    case mimeVersion
    /// The Content-Type header field.
    case contentType
    /// The Content-Disposition header field.
    case contentDisposition
    /// The Content-Transfer-Encoding header field.
    case contentTransferEncoding
    /// The Content-Description header field.
    case contentDescription
    /// The Content-Id header field.
    case contentId
    /// The Content-Base header field.
    case contentBase
    /// The Content-Language header field.
    case contentLanguage
    /// The Content-Location header field.
    case contentLocation
    /// The Content-Md5 header field.
    case contentMd5
    /// The Content-Length header field.
    case contentLength
    /// The Content-Duration header field.
    case contentDuration
    /// The Importance header field.
    case importance
    /// The Priority header field.
    case priority
    /// The X-Priority header field.
    case xPriority
    /// The Sensitivity header field.
    case sensitivity
    /// The Return-Path header field.
    case returnPath
    /// The Received header field.
    case received
    /// The Comments header field.
    case comments
    /// The Disposition-Notification-To header field.
    case dispositionNotificationTo
    /// The Disposition-Notification-Options header field.
    case dispositionNotificationOptions
    /// The List-Archive header field.
    case listArchive
    /// The List-Help header field.
    case listHelp
    /// The List-Id header field.
    case listId
    /// The List-Owner header field.
    case listOwner
    /// The List-Post header field.
    case listPost
    /// The List-Subscribe header field.
    case listSubscribe
    /// The List-Unsubscribe header field.
    case listUnsubscribe
    /// The List-Unsubscribe-Post header field.
    case listUnsubscribePost
    /// The ARC-Authentication-Results header field.
    case arcAuthenticationResults
    /// The Authentication-Results header field.
    case authenticationResults
    /// The ARC-Message-Signature header field.
    case arcMessageSignature
    /// The ARC-Seal header field.
    case arcSeal
    /// The DKIM-Signature header field.
    case dkimSignature
}

public extension HeaderId {
    /// The header field name associated with this identifier.
    ///
    /// Converts the enum value into the equivalent header field name.
    /// For example, ``HeaderId/contentType`` returns "Content-Type".
    ///
    /// - Returns: The header field name as a string, or an empty string for ``HeaderId/unknown``.
    var headerName: String {
        switch self {
        case .unknown:
            return ""
        case .adHoc:
            return "Ad-Hoc"
        case .bcc:
            return "Bcc"
        case .cc:
            return "Cc"
        case .from:
            return "From"
        case .to:
            return "To"
        case .replyTo:
            return "Reply-To"
        case .sender:
            return "Sender"
        case .resentBcc:
            return "Resent-Bcc"
        case .resentCc:
            return "Resent-Cc"
        case .resentFrom:
            return "Resent-From"
        case .resentTo:
            return "Resent-To"
        case .resentReplyTo:
            return "Resent-Reply-To"
        case .resentSender:
            return "Resent-Sender"
        case .resentDate:
            return "Resent-Date"
        case .resentMessageId:
            return "Resent-Message-Id"
        case .originalMessageId:
            return "Original-Message-Id"
        case .date:
            return "Date"
        case .subject:
            return "Subject"
        case .messageId:
            return "Message-Id"
        case .inReplyTo:
            return "In-Reply-To"
        case .references:
            return "References"
        case .mimeVersion:
            return "MIME-Version"
        case .contentType:
            return "Content-Type"
        case .contentDisposition:
            return "Content-Disposition"
        case .contentTransferEncoding:
            return "Content-Transfer-Encoding"
        case .contentDescription:
            return "Content-Description"
        case .contentId:
            return "Content-Id"
        case .contentBase:
            return "Content-Base"
        case .contentLanguage:
            return "Content-Language"
        case .contentLocation:
            return "Content-Location"
        case .contentMd5:
            return "Content-Md5"
        case .contentLength:
            return "Content-Length"
        case .contentDuration:
            return "Content-Duration"
        case .importance:
            return "Importance"
        case .priority:
            return "Priority"
        case .xPriority:
            return "X-Priority"
        case .sensitivity:
            return "Sensitivity"
        case .returnPath:
            return "Return-Path"
        case .received:
            return "Received"
        case .comments:
            return "Comments"
        case .dispositionNotificationTo:
            return "Disposition-Notification-To"
        case .dispositionNotificationOptions:
            return "Disposition-Notification-Options"
        case .listArchive:
            return "List-Archive"
        case .listHelp:
            return "List-Help"
        case .listId:
            return "List-Id"
        case .listOwner:
            return "List-Owner"
        case .listPost:
            return "List-Post"
        case .listSubscribe:
            return "List-Subscribe"
        case .listUnsubscribe:
            return "List-Unsubscribe"
        case .listUnsubscribePost:
            return "List-Unsubscribe-Post"
        case .arcAuthenticationResults:
            return "ARC-Authentication-Results"
        case .authenticationResults:
            return "Authentication-Results"
        case .arcMessageSignature:
            return "ARC-Message-Signature"
        case .arcSeal:
            return "ARC-Seal"
        case .dkimSignature:
            return "DKIM-Signature"
        }
    }

    /// Creates a ``HeaderId`` from a header field name string.
    ///
    /// Looks up the header field name in the mapping table and returns the
    /// corresponding ``HeaderId``. The lookup is case-insensitive.
    ///
    /// - Parameter field: The header field name to look up.
    ///
    /// - Returns: The corresponding ``HeaderId``, or ``HeaderId/unknown`` if the
    ///            field name is not recognized.
    static func from(field: String) -> HeaderId {
        let key = field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return HeaderIdMappings.byName[key] ?? .unknown
    }
}

private enum HeaderIdMappings {
    static let byName: [String: HeaderId] = {
        var mapping: [String: HeaderId] = [:]
        for id in HeaderId.allCases where id != .unknown {
            mapping[id.headerName.lowercased()] = id
        }
        return mapping
    }()
}
