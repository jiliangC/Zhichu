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
// MimeStream+Async.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Extension providing async/await support for ``MimeStream`` operations.
public extension MimeStream {
    /// Asynchronously reads a sequence of bytes from the stream.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes to store the read data.
    ///   - offset: The zero-based byte offset in `buffer` at which to begin storing data.
    ///   - count: The maximum number of bytes to read.
    ///
    /// - Returns: The total number of bytes read into the buffer.
    ///
    /// - Throws: Any errors thrown by the underlying stream's read method.
    func readAsync(_ buffer: inout [UInt8], offset: Int, count: Int) async throws -> Int {
        try read(&buffer, offset: offset, count: count)
    }

    /// Asynchronously writes a sequence of bytes to the stream.
    ///
    /// - Parameters:
    ///   - buffer: An array of bytes containing the data to write.
    ///   - offset: The zero-based byte offset in `buffer` from which to begin copying bytes.
    ///   - count: The number of bytes to be written.
    ///
    /// - Throws: Any errors thrown by the underlying stream's write method.
    func writeAsync(_ buffer: [UInt8], offset: Int, count: Int) async throws {
        try write(buffer, offset: offset, count: count)
    }

    /// Asynchronously clears all buffers for this stream.
    ///
    /// - Throws: Any errors thrown by the underlying stream's flush method.
    func flushAsync() async throws {
        try flush()
    }

    /// Copies all bytes from the current stream to a destination stream.
    ///
    /// - Parameters:
    ///   - destination: The stream to which the contents of the current stream will be copied.
    ///   - bufferSize: The size of the buffer to use for copying. Defaults to 4096 bytes.
    ///
    /// - Throws: Any errors thrown during reading from the source or writing to the destination.
    func copyTo(_ destination: MimeStream, bufferSize: Int = 4096) throws {
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while true {
            let nread = try read(&buffer, offset: 0, count: buffer.count)
            if nread == 0 {
                break
            }
            try destination.write(buffer, offset: 0, count: nread)
        }
    }

    /// Asynchronously copies all bytes from the current stream to a destination stream.
    ///
    /// - Parameters:
    ///   - destination: The stream to which the contents of the current stream will be copied.
    ///   - bufferSize: The size of the buffer to use for copying. Defaults to 4096 bytes.
    ///
    /// - Throws: Any errors thrown during reading from the source or writing to the destination.
    func copyToAsync(_ destination: MimeStream, bufferSize: Int = 4096) async throws {
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while true {
            let nread = try await readAsync(&buffer, offset: 0, count: buffer.count)
            if nread == 0 {
                break
            }
            try await destination.writeAsync(buffer, offset: 0, count: nread)
        }
    }
}
