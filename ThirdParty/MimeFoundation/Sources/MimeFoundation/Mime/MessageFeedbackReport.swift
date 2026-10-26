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
// MessageFeedbackReport.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public final class MessageFeedbackReport: MimePart {
    private var fieldsStorage: HeaderList
    private var fieldsLoaded = false

    private static var feedbackReportContentType: ContentType {
        guard let ct = try? ContentType("message", "feedback-report") else {
            preconditionFailure("Invalid static content type - this is a programming error")
        }
        return ct
    }

    public override init(_ contentType: ContentType) {
        self.fieldsStorage = HeaderList()
        super.init(contentType)
        configureFields()
        fieldsLoaded = false
    }

    public init() {
        self.fieldsStorage = HeaderList()
        super.init(Self.feedbackReportContentType)
        configureFields()
        fieldsLoaded = true
        updateContentFromFields()
    }

    public var fields: HeaderList {
        loadFieldsIfNeeded()
        return fieldsStorage
    }

    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }

    private func configureFields() {
        fieldsStorage.changed = { [weak self] _, _ in
            self?.updateContentFromFields()
        }
    }

    private func loadFieldsIfNeeded() {
        guard !fieldsLoaded else { return }
        fieldsLoaded = true

        let headers = HeaderList()
        headers.changed = { [weak self] _, _ in
            self?.updateContentFromFields()
        }
        fieldsStorage = headers

        guard let content else { return }
        let bytes = MessageFeedbackReport.readDecodedBytes(from: content)
        let (parsed, _) = MimeMessage.parseHeaders(bytes)
        for header in parsed {
            fieldsStorage.add(header)
        }
    }

    private func updateContentFromFields() {
        guard fieldsLoaded else { return }
        let options = FormatOptions.default
        var text = fieldsStorage.toString(options, encode: true)
        if !text.isEmpty {
            text.append(options.newLine)
        }
        let bytes = Array(text.utf8)
        content = MimeContent(MemoryStream(bytes, writable: false), encoding: .default)
    }

    private static func readDecodedBytes(from content: MimeContent) -> [UInt8] {
        let memory = MemoryStream()
        _ = try? content.decodeTo(memory)
        return memory.toByteArray()
    }
}
