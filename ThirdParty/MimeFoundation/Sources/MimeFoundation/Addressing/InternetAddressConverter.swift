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
// InternetAddressConverter.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

public struct InternetAddressConverter: Sendable {
    private let options: ParserOptions

    public init(options: ParserOptions = .default) {
        self.options = options
    }

    public func canConvertFrom(_ sourceType: Any.Type) -> Bool {
        sourceType == String.self
    }

    public func canConvertTo(_ destinationType: Any.Type) -> Bool {
        destinationType == String.self
    }

    public func convertFrom(_ value: Any) throws -> InternetAddress {
        guard let text = value as? String else {
            throw ConverterError.notSupported
        }
        return try InternetAddress.parsed(from: text, options: options)
    }

    public func convertTo(_ value: Any, destinationType: Any.Type) throws -> Any {
        guard destinationType == String.self, let address = value as? InternetAddress else {
            throw ConverterError.notSupported
        }
        return address.formatted(with: .default, encoded: false)
    }

    public func isValid(_ value: Any?) -> Bool {
        guard let text = value as? String else {
            return false
        }
        return (try? InternetAddress.parsed(from: text, options: options)) != nil
    }

    public static func register(_ options: ParserOptions? = nil) async throws {
        try await InternetAddressConverterRegistry.shared.register(options ?? .default)
    }

    public static func registeredConverter() async -> InternetAddressConverter {
        await InternetAddressConverterRegistry.shared.converter()
    }
}

private actor InternetAddressConverterRegistry {
    static let shared = InternetAddressConverterRegistry()
    private var options: ParserOptions? = nil
    private var isRegistered = false

    func register(_ options: ParserOptions) throws {
        guard !isRegistered else {
            throw ConverterError.alreadyRegistered
        }
        isRegistered = true
        self.options = options
    }

    func converter() -> InternetAddressConverter {
        InternetAddressConverter(options: options ?? .default)
    }
}
