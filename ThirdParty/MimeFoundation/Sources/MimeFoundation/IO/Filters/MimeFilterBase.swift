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
// MimeFilterBase.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A base implementation for MIME filters.
///
/// ``MimeFilterBase`` provides the common infrastructure needed by most filter
/// implementations, including input buffering and output buffer management.
///
/// ## Overview
///
/// This class handles the complexity of:
/// - Buffering partial input data between filter calls
/// - Managing output buffer allocation and resizing
/// - Combining preloaded data with new input
/// - Validating input parameters
///
/// Subclasses only need to implement the core filtering logic in
/// ``filter(_:startIndex:length:outputIndex:outputLength:flush:)``.
///
/// ## Subclassing Notes
///
/// When subclassing ``MimeFilterBase``:
///
/// 1. Override ``filter(_:startIndex:length:outputIndex:outputLength:flush:)``
///    to implement your filtering logic.
///
/// 2. Use ``ensureOutputSize(_:preserve:)`` to allocate space for output data.
///
/// 3. Use ``saveRemainingInput(_:startIndex:length:)`` to buffer incomplete
///    input sequences for the next filter call.
///
/// 4. Override ``reset()`` if you have additional state to clear, but remember
///    to call `super.reset()`.
///
/// ## Example
///
/// ```swift
/// class MyFilter: MimeFilterBase {
///     override func filter(_ input: [UInt8], startIndex: Int, length: Int,
///                         outputIndex: inout Int, outputLength: inout Int,
///                         flush: Bool) -> [UInt8] {
///         ensureOutputSize(length, preserve: false)
///         var output = outputBuffer
///         // ... process input into output ...
///         outputIndex = 0
///         outputLength = processedLength
///         return output
///     }
/// }
/// ```
open class MimeFilterBase: MimeFilter {
    private var preload: [UInt8] = []
    private var preloadLength: Int = 0
    private var inputBuffer: [UInt8] = []
    internal var outputBuffer: [UInt8] = []

    /// Initializes a new instance of the ``MimeFilterBase`` class.
    public init() {}

    /// Resets the filter to its initial state.
    ///
    /// Clears any internally buffered input data. Subclasses should override
    /// this method to reset additional state, but must call `super.reset()`.
    open func reset() {
        preloadLength = 0
    }

    /// Filters the specified input.
    ///
    /// This method handles preloading any buffered data from previous calls,
    /// validates arguments, and delegates to the subclass implementation of
    /// ``filter(_:startIndex:length:outputIndex:outputLength:flush:)``.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to filter.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The number of bytes of the input to filter.
    ///   - outputIndex: When this method returns, contains the starting index of the output in the returned buffer.
    ///   - outputLength: When this method returns, contains the length of the output buffer.
    ///
    /// - Returns: The filtered output buffer.
    open func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int) -> [UInt8] {
        try? validateArguments(input, startIndex: startIndex, length: length)
        var start = startIndex
        var count = length
        let prepared = prefilter(input, startIndex: &start, length: &count)
        return filter(prepared, startIndex: start, length: count, outputIndex: &outputIndex, outputLength: &outputLength, flush: false)
    }

    /// Filters the specified input, flushing all internally buffered data to the output.
    ///
    /// This method handles preloading any buffered data from previous calls,
    /// validates arguments, and delegates to the subclass implementation of
    /// ``filter(_:startIndex:length:outputIndex:outputLength:flush:)`` with `flush` set to `true`.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to filter.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The number of bytes of the input to filter.
    ///   - outputIndex: When this method returns, contains the starting index of the output in the returned buffer.
    ///   - outputLength: When this method returns, contains the length of the output buffer.
    ///
    /// - Returns: The filtered output buffer.
    open func flush(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int) -> [UInt8] {
        try? validateArguments(input, startIndex: startIndex, length: length)
        var start = startIndex
        var count = length
        let prepared = prefilter(input, startIndex: &start, length: &count)
        return filter(prepared, startIndex: start, length: count, outputIndex: &outputIndex, outputLength: &outputLength, flush: true)
    }

    /// The core filtering method that subclasses must override.
    ///
    /// This method performs the actual filtering operation. The default implementation
    /// simply returns the input unchanged (pass-through behavior).
    ///
    /// Subclasses should override this method to implement their specific filtering logic.
    ///
    /// - Parameters:
    ///   - input: The input buffer containing data to filter.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The length of the input buffer, starting at `startIndex`.
    ///   - outputIndex: When this method returns, contains the starting index of the output in the returned buffer.
    ///   - outputLength: When this method returns, contains the length of the output buffer.
    ///   - flush: If `true`, all internally buffered data should be flushed to the output buffer.
    ///
    /// - Returns: The filtered output buffer.
    open func filter(_ input: [UInt8], startIndex: Int, length: Int, outputIndex: inout Int, outputLength: inout Int, flush: Bool) -> [UInt8] {
        outputIndex = startIndex
        outputLength = length
        return input
    }

    /// Ensures that the output buffer is large enough to hold the specified number of bytes.
    ///
    /// This method allocates or resizes the ``outputBuffer`` as needed. The buffer size
    /// is always rounded up to the nearest multiple of 64 bytes for efficiency.
    ///
    /// - Parameters:
    ///   - need: The minimum size needed for the output buffer.
    ///   - preserve: If `true`, the current output buffer contents are preserved;
    ///     if `false`, the buffer can be reallocated without copying existing data.
    internal func ensureOutputSize(_ need: Int, preserve: Bool) {
        if outputBuffer.count < need {
            let size = (need + 63) & ~63
            if preserve && !outputBuffer.isEmpty {
                var newBuffer = outputBuffer
                newBuffer.append(contentsOf: repeatElement(0, count: size - outputBuffer.count))
                outputBuffer = newBuffer
            } else {
                outputBuffer = Array(repeating: 0, count: size)
            }
        }
    }

    /// Gets the output buffer.
    ///
    /// Provides access to the internal output buffer for subclasses.
    internal var output: [UInt8] {
        outputBuffer
    }

    /// Saves the remaining input for the next round of processing.
    ///
    /// When a filter encounters incomplete data (such as a partial multi-byte sequence),
    /// it can use this method to buffer that data. On the next call to ``filter(_:startIndex:length:outputIndex:outputLength:)``
    /// or ``flush(_:startIndex:length:outputIndex:outputLength:)``, the saved data will be
    /// automatically prepended to the new input.
    ///
    /// - Parameters:
    ///   - input: The input buffer.
    ///   - startIndex: The starting index of the data to save.
    ///   - length: The length of the data to save, starting at `startIndex`.
    internal func saveRemainingInput(_ input: [UInt8], startIndex: Int, length: Int) {
        if length == 0 {
            preloadLength = 0
            return
        }
        if preload.count < length {
            preload = Array(repeating: 0, count: length)
        }
        preload.replaceSubrange(0..<length, with: input[startIndex..<(startIndex + length)])
        preloadLength = length
    }

    private func prefilter(_ input: [UInt8], startIndex: inout Int, length: inout Int) -> [UInt8] {
        if preloadLength == 0 {
            return input
        }
        let totalLength = length + preloadLength
        if inputBuffer.count < totalLength {
            inputBuffer = Array(repeating: 0, count: (totalLength + 63) & ~63)
        }
        if preloadLength > 0 {
            inputBuffer.replaceSubrange(0..<preloadLength, with: preload[0..<preloadLength])
        }
        inputBuffer.replaceSubrange(preloadLength..<(preloadLength + length), with: input[startIndex..<(startIndex + length)])
        length = totalLength
        startIndex = 0
        preloadLength = 0
        return inputBuffer
    }

    private func validateArguments(_ input: [UInt8], startIndex: Int, length: Int) throws {
        if startIndex < 0 || startIndex > input.count {
            throw StreamError.outOfRange
        }
        if length < 0 || length > (input.count - startIndex) {
            throw StreamError.outOfRange
        }
    }
}
