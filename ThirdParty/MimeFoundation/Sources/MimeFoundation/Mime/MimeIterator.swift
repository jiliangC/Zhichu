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
// MimeIterator.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public enum MimeIteratorError: Error, Equatable, Sendable {
    case invalidPathSpecifier
    case emptyPathSpecifier
}

public final class MimeIterator {
    private struct Node {
        let entity: MimeEntity
        let indexed: Bool
    }

    public let message: MimeMessage

    private var stack: [Node] = []
    private var path: [Int] = []
    private var moveFirst = true
    private var currentEntity: MimeEntity? = nil
    private var index: Int = -1

    public init(_ message: MimeMessage) {
        self.message = message
    }

    public var current: MimeEntity? {
        currentEntity
    }

    public var parent: MimeEntity? {
        guard currentEntity != nil else { return nil }
        return stack.last?.entity
    }

    public var depth: Int {
        guard currentEntity != nil else { return 0 }
        return stack.count
    }

    public var pathSpecifier: String? {
        guard currentEntity != nil else { return nil }
        var components: [String] = []
        for value in path {
            components.append(String(value + 1))
        }
        components.append(String(index + 1))
        return components.joined(separator: ".")
    }

    public func moveNext() -> Bool {
        if moveFirst {
            currentEntity = message.body
            moveFirst = false
            return currentEntity != nil
        }

        if let messagePart = currentEntity as? MessagePart, let body = messagePart.message?.body {
            push(messagePart)
            currentEntity = body
            index = currentEntity is Multipart ? -1 : 0
            return true
        }

        if let multipart = currentEntity as? Multipart, multipart.count > 0 {
            push(multipart)
            currentEntity = multipart[0]
            index = 0
            return true
        }

        while !stack.isEmpty {
            if let multipart = stack.last?.entity as? Multipart {
                if multipart.count > index + 1 {
                    index += 1
                    currentEntity = multipart[index]
                    return true
                }
            }

            if !pop() {
                break
            }
        }

        currentEntity = nil
        index = -1
        return false
    }

    public func reset() {
        moveFirst = true
        currentEntity = nil
        stack.removeAll(keepingCapacity: true)
        path.removeAll(keepingCapacity: true)
        index = -1
    }

    public func moveTo(_ pathSpecifier: String) throws -> Bool {
        guard !pathSpecifier.isEmpty else {
            throw MimeIteratorError.emptyPathSpecifier
        }
        let indexes = try parsePath(pathSpecifier)

        for i in 0..<min(indexes.count, path.count) {
            if indexes[i] < path[i] {
                reset()
                break
            }
        }

        if !moveFirst && indexes.count < path.count {
            reset()
        }

        if moveFirst && !moveNext() {
            return false
        }

        repeat {
            if path.count + 1 == indexes.count {
                var matched = true
                for i in 0..<path.count {
                    if indexes[i] != path[i] {
                        matched = false
                        break
                    }
                }
                if matched && indexes[indexes.count - 1] == index {
                    return true
                }
            }
        } while moveNext()

        return false
    }

    private func push(_ entity: MimeEntity) {
        if index != -1 {
            path.append(index)
        }
        stack.append(Node(entity: entity, indexed: index != -1))
    }

    private func pop() -> Bool {
        guard let node = stack.popLast() else { return false }
        if node.indexed, let last = path.popLast() {
            index = last
        }
        currentEntity = node.entity
        return true
    }

    private func parsePath(_ pathSpecifier: String) throws -> [Int] {
        let segments = pathSpecifier.split(separator: ".", omittingEmptySubsequences: false)
        var indexes: [Int] = []
        for segment in segments {
            guard let value = Int(segment), value >= 0 else {
                throw MimeIteratorError.invalidPathSpecifier
            }
            indexes.append(value - 1)
        }
        return indexes
    }
}
