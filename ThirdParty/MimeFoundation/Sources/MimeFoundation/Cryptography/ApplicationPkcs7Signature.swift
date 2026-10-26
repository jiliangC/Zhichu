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
// ApplicationPkcs7Signature.swift
//
// MIME part for S/MIME detached signatures.
//

import Foundation

/// An `application/pkcs7-signature` MIME part containing a detached S/MIME signature.
///
/// This class represents a PKCS#7/CMS detached signature, typically used as the
/// second part of a ``MultipartSigned`` message. The signature part contains the
/// cryptographic signature data without the signed content itself.
///
/// ## Usage
///
/// ``ApplicationPkcs7Signature`` parts are typically created automatically when
/// using ``MultipartSigned/create(_:signer:context:)`` or ``SecureMimeContext/createSignature(_:entity:)``.
///
/// ```swift
/// // Create a signed message
/// let signer = try CmsSigner(certificatePath: "cert.pem", privateKeyPath: "key.pem")
/// let context = SecureMimeContext()
/// let signature = try context.createSignature(signer, entity: entity)
/// ```
///
/// ## Topics
///
/// ### Creating a Signature Part
/// - ``init()``
/// - ``init(_:)-7g4gg``
/// - ``init(_:)-2nxof``
///
/// ### Accessing Signature Data
/// - ``getSignatureBytes()``
public class ApplicationPkcs7Signature: MimePart {

    /// Creates a new empty PKCS#7 signature part with the default content type.
    ///
    /// The content type is set to `application/pkcs7-signature` with a
    /// `name` parameter of `smime.p7s`, and the content transfer encoding
    /// is set to Base64.
    public convenience init() {
        self.init(ApplicationPkcs7Signature.defaultContentType)
        contentTransferEncoding = .base64
    }

    /// Creates a new PKCS#7 signature part from signature bytes.
    ///
    /// - Parameter signatureBytes: The raw CMS/PKCS#7 signature bytes.
    public convenience init(_ signatureBytes: [UInt8]) {
        self.init()
        let stream = MemoryStream(signatureBytes, writable: false)
        content = MimeContent(stream, encoding: .binary)
    }

    /// Creates a new PKCS#7 signature part from signature data.
    ///
    /// - Parameter signatureData: The raw CMS/PKCS#7 signature data.
    public convenience init(_ signatureData: Data) {
        self.init(Array(signatureData))
    }

    /// The default content type for PKCS#7 signatures.
    private static var defaultContentType: ContentType {
        let ct = try! ContentType("application", "pkcs7-signature")
        ct.parameters["name"] = "smime.p7s"
        return ct
    }

    /// Returns the raw signature bytes.
    ///
    /// Decodes the signature content (which is typically Base64-encoded) and
    /// returns the raw CMS/PKCS#7 signature bytes.
    ///
    /// - Returns: The raw CMS signature bytes.
    /// - Throws: ``SecureMimeError/invalidSignatureData(_:)`` if the signature
    ///   content cannot be read or decoded.
    public func getSignatureBytes() throws -> [UInt8] {
        guard let content = content else {
            throw SecureMimeError.invalidSignatureData("No signature content")
        }
        return try readAllBytes(content: content)
    }

    /// Accepts a MIME visitor.
    ///
    /// - Parameter visitor: The visitor to accept.
    public override func accept(_ visitor: MimeVisitor) {
        visitor.visit(self)
    }
}
