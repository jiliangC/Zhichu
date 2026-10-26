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
// MultipartReport.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A multipart/report MIME entity.
///
/// A ``MultipartReport`` is a specialized multipart entity used for returning
/// delivery status notifications, disposition notifications, or other types of reports.
/// The first part typically contains a human-readable description of the report,
/// and subsequent parts contain machine-readable report data.
///
/// ## Topics
///
/// ### Creating Multipart Report Entities
/// - ``init(reportType:_:)``
/// - ``init(reportType:args:)``
/// - ``init(_:)``
///
/// ### Report Type
/// - ``reportType``
/// - ``setReportType(_:)``
public final class MultipartReport: Multipart {
    public override init(_ contentType: ContentType) {
        super.init(contentType)
    }

    public convenience init(reportType: String, _ args: Any?...) throws {
        try self.init(reportType: reportType, args: args)
    }

    public init(reportType: String, args: [Any?]) throws {
        try super.init("report")
        try applyArgs(args)
        try setReportType(reportType)
    }

    public override init(_ reportType: String) throws {
        try super.init("report")
        try setReportType(reportType)
    }

    /// The type of report.
    ///
    /// The report type is specified in the "report-type" parameter of the Content-Type
    /// header. Common values include "delivery-status", "disposition-notification",
    /// and "feedback-report".
    public var reportType: String? {
        get {
            contentType.parameters["report-type"]
        }
        set {
            if let newValue {
                _ = try? setReportType(newValue)
            } else {
                contentType.parameters["report-type"] = nil
            }
        }
    }

    /// Sets the type of report.
    ///
    /// - Parameter value: The report type (e.g., "delivery-status", "disposition-notification").
    /// - Throws: An error if the operation fails.
    public func setReportType(_ value: String) throws {
        if reportType == value {
            return
        }

        contentType.parameters["report-type"] = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }
}
