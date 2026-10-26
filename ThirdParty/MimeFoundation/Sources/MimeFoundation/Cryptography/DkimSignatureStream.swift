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
// DkimSignatureStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

final class DkimSignatureStream: MimeStream {
    private let signer: DkimSignatureContext
    private var currentLength: Int = 0
    private var closed = false

    init(_ signer: DkimSignatureContext?) throws {
        guard let signer else {
            throw StreamError.invalidArgument
        }
        self.signer = signer
    }

    func generateSignature() throws -> [UInt8] {
        try signer.generateSignature()
    }

    func verifySignature(_ signature: String?) throws -> Bool {
        guard let signature else {
            throw StreamError.invalidArgument
        }
        guard let data = Data(base64Encoded: signature, options: [.ignoreUnknownCharacters]) else {
            throw StreamError.invalidArgument
        }
        return try signer.verify(signature: Array(data))
    }

    var canRead: Bool { false }
    var canWrite: Bool { true }
    var canSeek: Bool { false }
    var canTimeout: Bool { false }

    var readTimeout: Int {
        get { 0 }
        set { }
    }

    var writeTimeout: Int {
        get { 0 }
        set { }
    }

    var position: Int {
        get { currentLength }
        set { _ = try? seek(newValue, origin: .begin) }
    }

    var length: Int { currentLength }

    func read(_ buffer: inout [UInt8], offset: Int, count: Int) throws -> Int {
        try ensureOpen()
        throw StreamError.notSupported
    }

    func write(_ buffer: [UInt8], offset: Int, count: Int) throws {
        try ensureOpen()
        guard offset >= 0, count >= 0, offset + count <= buffer.count else {
            throw StreamError.invalidArgument
        }
        guard count > 0 else {
            return
        }

        signer.update(buffer, offset: offset, count: count)
        currentLength += count
    }

    func seek(_ offset: Int, origin: SeekOrigin) throws -> Int {
        try ensureOpen()
        throw StreamError.notSupported
    }

    func flush() throws {
        try ensureOpen()
    }

    func close() {
        closed = true
    }

    private func ensureOpen() throws {
        if closed {
            throw StreamError.closed
        }
    }
}
