# ``MimeFoundation``

A comprehensive Swift library for creating, parsing, and manipulating MIME messages.

## Overview

MimeFoundation is a full-featured MIME message library for Swift, providing everything you need to work with email messages and MIME content. It supports:

- **Message Parsing**: Load and parse RFC 2822/5322 compliant email messages
- **Message Creation**: Build messages programmatically with attachments, HTML content, and more
- **S/MIME Security**: Sign and encrypt messages using industry-standard cryptography
- **DKIM Signing**: Add DomainKeys Identified Mail signatures for email authentication
- **International Support**: Full support for internationalized headers and content

MimeFoundation is designed for performance and correctness, with stream-based processing for efficient handling of large messages and strict adherence to relevant RFCs.

```swift
// Create a simple email message
let message = MimeMessage()
message.from.add(MailboxAddress(name: "Alice", address: "alice@example.com"))
message.to.add(MailboxAddress(name: "Bob", address: "bob@example.com"))
message.subject = "Hello from MimeFoundation!"
message.body = TextPart("plain", "This is the message body.")
```

## Topics

### Getting Started

- <doc:Installation>
- <doc:QuickStart>

### Creating and Parsing Messages

- <doc:CreatingMessages>
- <doc:ParsingMessages>
- <doc:WorkingWithHeaders>
- <doc:AddressesAndRecipients>

### Working with Content

- <doc:TextContent>
- <doc:Attachments>
- <doc:MultipartMessages>
- <doc:EncodingAndCharsets>
- <doc:TNEFMessages>

### Security and Cryptography

- <doc:SMIMEOverview>
- <doc:SigningMessages>
- <doc:EncryptingMessages>
- <doc:VerifyingSignatures>
- <doc:CertificateManagement>
- <doc:DKIMSigning>

### Advanced Topics

- <doc:StreamProcessing>
- <doc:MessageIteration>
- <doc:ParserConfiguration>
- <doc:FormatConfiguration>

### Core Types

- ``MimeMessage``
- ``MimeEntity``
- ``MimePart``
- ``TextPart``
- ``Multipart``
- ``MessagePart``
- ``TnefPart``

### Addressing

- ``InternetAddress``
- ``MailboxAddress``
- ``GroupAddress``
- ``InternetAddressList``

### Headers

- ``Header``
- ``HeaderId``
- ``HeaderList``

### Content Types

- ``ContentType``
- ``ContentDisposition``
- ``ContentEncoding``

### Cryptography

- ``SecureMimeContext``
- ``CmsSigner``
- ``CmsRecipient``
- ``DkimSigner``
- ``DkimVerifier``

### Certificate Management

- ``X509CertificateStore``
- ``X509CertificateRecord``
- ``X509CertificateDatabaseProtocol``
- ``SqliteCertificateDatabase``
- ``X509ChainValidator``
- ``ChainValidationResult``
- ``ChainValidationError``
- ``X509KeyUsageFlags``

### Parsing and I/O

- ``MimeParser``
- ``MimeStream``
- ``FormatOptions``
- ``ParserOptions``
