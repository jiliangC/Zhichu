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
// DkimHashStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Crypto

final class DkimHashStream: MimeStream {
    private enum DigestState {
        case sha1(Insecure.SHA1)
        case sha256(SHA256)

        mutating func update(_ data: ArraySlice<UInt8>) {
            switch self {
            case .sha1(var digest):
                digest.update(data: data)
                self = .sha1(digest)
            case .sha256(var digest):
                digest.update(data: data)
                self = .sha256(digest)
            }
        }

        func finalize() -> [UInt8] {
            switch self {
            case .sha1(let digest):
                let hash = digest.finalize()
                return Array(hash)
            case .sha256(let digest):
                let hash = digest.finalize()
                return Array(hash)
            }
        }
    }

    private var digest: DigestState
    private let maxLength: Int
    private var currentLength: Int = 0
    private var closed = false

    init(_ algorithm: DkimSignatureAlgorithm, maxLength: Int = -1) {
        switch algorithm {
        case .ed25519Sha256, .rsaSha256:
            digest = .sha256(SHA256())
        case .rsaSha1:
            digest = .sha1(Insecure.SHA1())
        }
        self.maxLength = maxLength
    }

    func generateHash() -> [UInt8] {
        digest.finalize()
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

        let remaining: Int
        if maxLength >= 0 {
            remaining = max(0, maxLength - currentLength)
        } else {
            remaining = count
        }

        let toHash = min(count, remaining)
        if toHash > 0 {
            digest.update(buffer[offset..<(offset + toHash)])
            currentLength += toHash
        }
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
