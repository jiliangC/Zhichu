# Encoding and Charsets

Understand content transfer encodings and character sets in MIME messages.

## Overview

MIME uses two types of encoding: **character encoding** (charset) for text data, and **content transfer encoding** for transporting data safely over email systems. MimeFoundation handles both automatically while giving you full control when needed.

## Character Encoding (Charset)

Character encoding converts text to bytes. Common charsets include:

- **UTF-8**: Universal encoding, supports all Unicode characters
- **ISO-8859-1**: Western European (Latin-1)
- **ISO-2022-JP**: Japanese
- **Windows-1252**: Windows Western European

### Setting Charset

```swift
let textPart = TextPart("plain", "Hello, 世界!")

// UTF-8 is the default
print(textPart.contentType.charset)  // "utf-8"

// Set explicitly
textPart.contentType.charset = "utf-8"
```

### Charset Detection

When parsing, the library uses the charset from Content-Type:

```swift
// Content-Type: text/plain; charset=iso-8859-1
if let charset = textPart.contentType.charset {
    print("Document charset: \(charset)")
}
```

### Working with CharsetUtils

```swift
// Encode string to bytes
let bytes = CharsetUtils.getBytes("Hello", encoding: .utf8)

// Decode bytes to string
let text = CharsetUtils.getString(bytes, encoding: .utf8)
```

## Content Transfer Encoding

Content transfer encoding ensures binary data survives email transport. The ``ContentEncoding`` enum defines available encodings:

### Available Encodings

| Encoding | Use Case |
|----------|----------|
| `.sevenBit` | ASCII-only text |
| `.eightBit` | 8-bit text with CRLF line endings |
| `.binary` | Raw binary (no line length limits) |
| `.quotedPrintable` | Mostly ASCII text with some special characters |
| `.base64` | Binary data or non-ASCII text |
| `.uuEncode` | Legacy UNIX encoding |

### Setting Transfer Encoding

```swift
let part = MimePart()

// Automatic selection (recommended)
part.contentTransferEncoding = .default

// Explicit setting
part.contentTransferEncoding = .base64
```

### When to Use Each Encoding

**Quoted-Printable** - Best for text that's mostly ASCII:
```swift
// Good for: text with occasional special characters
// "Meeting at 3:00—don't be late!"
textPart.contentTransferEncoding = .quotedPrintable
```

**Base64** - Best for binary data:
```swift
// Good for: images, PDFs, executables, or any binary
imagePart.contentTransferEncoding = .base64
```

**7-bit/8-bit** - For plain ASCII:
```swift
// Good for: simple ASCII text
plainTextPart.contentTransferEncoding = .sevenBit
```

## Automatic Encoding Selection

The `prepare()` method selects optimal encoding:

```swift
// Prepare with 7-bit constraint (for SMTP)
try message.prepare(constraint: .sevenBit)

// Prepare with 8-bit constraint
try message.prepare(constraint: .eightBit)

// No constraint
try message.prepare(constraint: .none)
```

### Encoding Constraints

``EncodingConstraint`` specifies transport requirements:

- **`.none`**: No restrictions; use any encoding
- **`.sevenBit`**: ASCII-only; encodes non-ASCII as base64/quoted-printable
- **`.eightBit`**: 8-bit safe; still ensures CRLF line endings

## Header Encoding (RFC 2047)

Headers containing non-ASCII characters use RFC 2047 encoding:

```swift
// Subject with international characters
message.subject = "日本語の件名"

// Automatically encoded in the raw message as:
// Subject: =?UTF-8?B?5pel5pys6Kqe44Gu5Lu25ZCN?=
```

### RFC 2047 Methods

- **Q-encoding**: Similar to quoted-printable, for mostly ASCII
- **B-encoding**: Base64, for text with many non-ASCII characters

```swift
// Decode RFC 2047 encoded text
let decoded = try Rfc2047.decodeText("=?UTF-8?B?SGVsbG8=?=")

// Encode text for headers
let encoded = Rfc2047.encodeText("こんにちは", charset: .utf8)
```

## Working with Encoders and Decoders

### Base64

```swift
// Encode
let encoder = Base64Encoder()
let encoded = encoder.encode(data)

// Decode
let decoder = Base64Decoder()
let decoded = try decoder.decode(encoded)
```

### Quoted-Printable

```swift
// Encode
let encoder = QuotedPrintableEncoder()
let encoded = encoder.encode(data)

// Decode
let decoder = QuotedPrintableDecoder()
let decoded = try decoder.decode(encoded)
```

## Stream-Based Encoding

For large content, use stream filters:

```swift
// Create a filtered stream that encodes on-the-fly
let outputStream = MemoryStream()
let encoderFilter = EncoderFilter(encoding: .base64)
let filteredStream = FilteredStream(stream: outputStream, filters: [encoderFilter])

// Write data; it's encoded automatically
try filteredStream.write(largeData)
```

## MIME Content with Encoding

``MimeContent`` handles encoded content:

```swift
let part = MimePart()

// Set content with encoding
part.content = MimeContent(data: binaryData)
part.contentTransferEncoding = .base64

// Read decoded content
if let content = part.content {
    let decoded = try content.read()  // Decodes automatically
}
```

## Format Options

Control encoding behavior during serialization:

```swift
var options = FormatOptions()

// Line length for encoded content
options.maxLineLength = 76  // Default, RFC compliant

// Parameter encoding method
options.parameterEncodingMethod = .rfc2231  // Modern
// or
options.parameterEncodingMethod = .rfc2045Quoted  // Legacy

// Allow international characters in headers
options.international = true

try message.writeTo(stream, options: options)
```

## Best Practices

### For Text Content

```swift
// Let the library choose encoding
let textPart = TextPart("plain", content)
// Prepare() will select optimal encoding
```

### For Binary Content

```swift
// Always use base64 for binary
let binaryPart = MimePart()
binaryPart.content = MimeContent(data: binaryData)
binaryPart.contentTransferEncoding = .base64
```

### For International Text

```swift
// Use UTF-8 charset
textPart.contentType.charset = "utf-8"
// Content transfer encoding will be base64 or quoted-printable
```

### For Maximum Compatibility

```swift
// Prepare with 7-bit constraint
try message.prepare(constraint: .sevenBit)
// Ensures the message works with all SMTP servers
```

## Encoding Examples

### Email with Japanese Text

```swift
let message = MimeMessage()
message.from.add(MailboxAddress(name: "田中太郎", address: "tanaka@example.jp"))
message.to.add(MailboxAddress(address: "recipient@example.com"))
message.subject = "日本語メールのテスト"  // Encoded as RFC 2047

let body = TextPart("plain", "こんにちは、これはテストメールです。")
body.contentType.charset = "utf-8"
message.body = body

// Prepare ensures proper encoding
try message.prepare(constraint: .sevenBit)
```

### Binary Attachment

```swift
let attachment = MimePart()
attachment.contentType.mediaType = "application"
attachment.contentType.mediaSubtype = "octet-stream"
attachment.contentTransferEncoding = .base64  // Required for binary
attachment.content = MimeContent(data: binaryBytes)
```

## Topics

### Related Types

- ``ContentEncoding``
- ``EncodingConstraint``
- ``FormatOptions``

### Related Articles

- <doc:TextContent>
- <doc:WorkingWithHeaders>
