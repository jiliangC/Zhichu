# Working with Headers

Access and manipulate message and entity headers.

## Overview

Headers are key-value pairs that carry metadata about messages and their parts. MimeFoundation provides comprehensive support for reading, modifying, and creating headers with proper RFC 2047 encoding for international characters.

## Understanding Headers

Every ``MimeMessage`` and ``MimeEntity`` has a ``HeaderList`` accessible via the `headers` property:

```swift
// Message headers
for header in message.headers {
    print("\(header.field): \(header.value)")
}

// Entity headers (for a MIME part)
if let part = message.body as? MimePart {
    for header in part.headers {
        print("\(header.field): \(header.value)")
    }
}
```

## Standard Headers

Use ``HeaderId`` for type-safe access to standard headers:

```swift
// Get a header by ID
if let contentType = message.headers[.contentType] {
    print("Content-Type: \(contentType.value)")
}

// Check if a header exists
let hasSubject = message.headers.contains(.subject)

// Get the raw value (before decoding)
if let header = message.headers[.subject] {
    let rawBytes = header.rawValue  // Original bytes
    let decoded = header.value       // Decoded string
}
```

Common header IDs include:

- **Message headers**: `.from`, `.to`, `.cc`, `.bcc`, `.subject`, `.date`, `.messageId`
- **Content headers**: `.contentType`, `.contentDisposition`, `.contentTransferEncoding`
- **Threading**: `.inReplyTo`, `.references`
- **Authentication**: `.dkimSignature`, `.authenticationResults`

## Setting Headers

Set headers using the ``HeaderList`` methods:

```swift
// Set a header (replaces existing)
try message.headers.set(id: .subject, value: "New Subject")

// Set using field name
try message.headers.set(field: "X-Custom-Header", value: "custom value")

// Add a header (allows duplicates)
try message.headers.add(field: "Received", value: "from mail.example.com...")
try message.headers.add(field: "Received", value: "from smtp.example.com...")
```

## Removing Headers

Remove headers you don't need:

```swift
// Remove by ID
message.headers.remove(.bcc)

// Remove by field name
message.headers.remove(field: "X-Custom-Header")

// Remove all headers with a field name
message.headers.removeAll(field: "Received")
```

## Header Encoding

Headers containing non-ASCII characters are automatically encoded using RFC 2047:

```swift
// This subject will be encoded automatically
message.subject = "日本語の件名"

// The raw header becomes something like:
// Subject: =?UTF-8?B?5pel5pys6Kqe44Gu5Lu25ZCN?=

// Control encoding explicitly
let header = Header(id: .subject, value: "日本語", encoding: .utf8)
```

### RFC 2047 Encoding

The library handles RFC 2047 "encoded-word" syntax:

- **Q-encoding**: For mostly ASCII text with some special characters
- **B-encoding**: Base64 encoding for text with many non-ASCII characters

```swift
// Decode an RFC 2047 encoded string
let decoded = try Rfc2047.decodeText(encodedValue)

// Encode a string for use in headers
let encoded = Rfc2047.encodeText(text, charset: .utf8)
```

## Content-Type Header

The Content-Type header has special handling via ``ContentType``:

```swift
// Access structured content type
let contentType = part.contentType
print("Media type: \(contentType.mediaType)")
print("Subtype: \(contentType.mediaSubtype)")
print("MIME type: \(contentType.mimeType)")  // e.g., "text/plain"

// Access parameters
let charset = contentType.charset  // e.g., "utf-8"
let boundary = contentType.boundary  // For multipart

// Modify content type
part.contentType.charset = "utf-8"
try part.contentType.parameters.set("name", value: "document.txt")
```

## Content-Disposition Header

The Content-Disposition header controls attachment behavior:

```swift
// Access structured disposition
if let disposition = part.contentDisposition {
    print("Is attachment: \(disposition.isAttachment)")
    print("Filename: \(disposition.fileName ?? "none")")

    // Access parameters
    let creationDate = disposition.creationDate
    let modificationDate = disposition.modificationDate
}

// Set disposition
part.contentDisposition = try ContentDisposition(.attachment)
part.contentDisposition?.fileName = "report.pdf"
```

## Multiple Headers with Same Name

Some headers can appear multiple times (e.g., Received):

```swift
// Get all headers with a specific field
let receivedHeaders = message.headers.getAll(field: "Received")
for header in receivedHeaders {
    print(header.value)
}

// Add without replacing
try message.headers.add(field: "X-Tag", value: "important")
try message.headers.add(field: "X-Tag", value: "urgent")
```

## Header Iteration

Iterate through headers in order:

```swift
// All headers
for header in message.headers {
    print("\(header.field): \(header.value)")
}

// With index
for (index, header) in message.headers.enumerated() {
    print("[\(index)] \(header.field)")
}
```

## Raw Header Access

Access the original unparsed header bytes:

```swift
if let header = message.headers[.subject] {
    // Original bytes (useful for debugging or preservation)
    let rawBytes = header.rawValue

    // Check if header was malformed
    if header.isInvalid {
        print("Warning: malformed header")
    }
}
```

## Creating Custom Headers

Create header instances directly:

```swift
// Using HeaderId
let header1 = Header(id: .xPriority, value: "1")

// Using field name
let header2 = Header(field: "X-Custom", value: "value")

// With specific encoding
let header3 = Header(field: "X-Name", value: "名前", encoding: .utf8)

// Add to header list
try message.headers.add(header: header1)
```

## Topics

### Related Types

- ``Header``
- ``HeaderId``
- ``HeaderList``
- ``ContentType``
- ``ContentDisposition``

### Related Articles

- <doc:EncodingAndCharsets>
