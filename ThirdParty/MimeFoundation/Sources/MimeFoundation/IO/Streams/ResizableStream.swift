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
// ResizableStream.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// A protocol for streams that support resizing their length.
///
/// ``ResizableStream`` extends ``MimeStream`` to provide the ability to
/// explicitly set the stream's length, which may involve truncating or
/// expanding the stream's storage.
///
/// ## Overview
///
/// Streams that conform to this protocol allow their length to be changed
/// programmatically. When the length is reduced, data beyond the new length
/// is discarded. When the length is increased, the new space is typically
/// filled with zeros.
public protocol ResizableStream: MimeStream {
    /// Sets the length of the stream.
    ///
    /// If the specified value is less than the current length, the stream is truncated.
    /// If the specified value is larger than the current length, the stream is expanded
    /// and the new bytes are typically initialized to zero.
    ///
    /// - Parameter length: The desired length of the stream in bytes.
    ///
    /// - Throws: ``StreamError/closed`` if the stream has been closed,
    ///   ``StreamError/notSupported`` if the stream does not support resizing,
    ///   or ``StreamError/outOfRange`` if `length` is negative.
    func setLength(_ length: Int) throws
}
