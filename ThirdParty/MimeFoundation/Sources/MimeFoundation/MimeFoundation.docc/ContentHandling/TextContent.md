# Text Content

Work with plain text and HTML message bodies.

## Overview

Text content is the foundation of most email messages. MimeFoundation provides ``TextPart`` for handling text bodies with proper character encoding, content type management, and format detection.

## Creating Text Parts

Create text parts using the ``TextPart`` initializer:

```swift
// Plain text
let plainPart = TextPart("plain", "Hello, World!")

// HTML
let htmlPart = TextPart("html", """
    <html>
    <body>
        <h1>Hello, World!</h1>
    </body>
    </html>
    """)

// Rich text (RTF)
let rtfPart = TextPart("rtf", rtfContent)
```

## Accessing Text Content

Read text from a TextPart:

```swift
if let textPart = message.body as? TextPart {
    // Get the text content
    let text = textPart.text

    // Check the format
    if textPart.isHtml {
        print("HTML content")
    } else if textPart.isPlain {
        print("Plain text")
    }
}
```

## Quick Body Access

``MimeMessage`` provides convenience properties for common cases:

```swift
// Get plain text body (searches through multipart if needed)
if let plainText = message.textBody {
    print("Plain text: \(plainText)")
}

// Get HTML body
if let htmlText = message.htmlBody {
    print("HTML: \(htmlText)")
}
```

These properties handle the common pattern of multipart/alternative bodies.

## Character Encoding

Text parts manage character encoding automatically:

```swift
let textPart = TextPart("plain", "日本語テキスト")

// Default encoding is UTF-8
print(textPart.contentType.charset)  // "utf-8"

// Set a specific encoding
textPart.contentType.charset = "iso-2022-jp"

// The text is re-encoded when written
```

### Encoding Detection

When reading text content, the library uses:

1. The charset parameter from Content-Type header
2. Charset detection from content (if header is missing)
3. Fallback to UTF-8 or ISO-8859-1

```swift
// For parsed messages
if let textPart = message.body as? TextPart {
    let charset = textPart.contentType.charset ?? "unknown"
    print("Detected charset: \(charset)")
}
```

## Format=Flowed Text

RFC 3676 format=flowed allows proper reflowing of plain text:

```swift
// Create format=flowed text
let textPart = TextPart("plain", text)
try textPart.contentType.parameters.set("format", value: "flowed")

// Read flowed text
if textPart.contentType.parameters["format"] == "flowed" {
    // Content follows format=flowed conventions
}
```

## HTML to Plain Text Conversion

Convert between HTML and plain text:

```swift
// Use TextConverter for conversions
let plainText = TextConverter.htmlToPlain(htmlContent)
let htmlFromPlain = TextConverter.plainToHtml(plainText)
```

## Multipart Alternative

Best practice is providing both plain and HTML versions:

```swift
let alternative = try MultipartAlternative()

// Plain text (fallback) comes first
let plain = TextPart("plain", "Hello, this is *important* text.")
try alternative.add(plain)

// HTML (preferred) comes last
let html = TextPart("html", """
    <html>
    <body>
        <p>Hello, this is <strong>important</strong> text.</p>
    </body>
    </html>
    """)
try alternative.add(html)

message.body = alternative
```

## Inline Content

For text that should display inline (not as attachment):

```swift
let textPart = TextPart("plain", content)
textPart.contentDisposition = try ContentDisposition(.inline)
```

## Content-ID for References

Text parts can be referenced by Content-ID (useful in multipart/related):

```swift
let htmlPart = TextPart("html", """
    <img src="cid:logo123">
    """)

// The image part would have:
// imagePart.contentId = "logo123"
```

## Reading from Streams

Create text parts from existing content:

```swift
// From bytes
let bytes: [UInt8] = // ... encoded text
let content = MimeContent(data: bytes, encoding: .utf8)
let textPart = TextPart()
textPart.content = content

// The text property handles decoding
let text = textPart.text
```

## Transfer Encoding

Control how text is encoded for transport:

```swift
let textPart = TextPart("plain", content)

// Let the library choose
textPart.contentTransferEncoding = .default

// Or specify explicitly
textPart.contentTransferEncoding = .quotedPrintable  // Good for mostly ASCII
textPart.contentTransferEncoding = .base64           // For binary or complex encoding
```

When calling `prepare()`, optimal encoding is selected automatically based on content.

## Handling Rich Text

While plain text and HTML are most common, other text types are supported:

```swift
// Calendar data
let calendarPart = TextPart("calendar", icsContent)
calendarPart.contentType.mediaType = "text"
calendarPart.contentType.mediaSubtype = "calendar"
try calendarPart.contentType.parameters.set("method", value: "REQUEST")

// XML
let xmlPart = TextPart("xml", xmlContent)
```

## Complete Example

```swift
let message = MimeMessage()
message.from.add(MailboxAddress(address: "sender@example.com"))
message.to.add(MailboxAddress(address: "recipient@example.com"))
message.subject = "Newsletter"

// Create multipart/alternative
let alternative = try MultipartAlternative()

// Plain text version
let plainText = """
    Welcome to Our Newsletter!

    This month's highlights:
    * New product launch
    * Customer spotlight
    * Tips and tricks

    Visit us at: https://example.com
    """
try alternative.add(TextPart("plain", plainText))

// HTML version with styling
let htmlText = """
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; }
            h1 { color: #333366; }
            ul { line-height: 1.8; }
        </style>
    </head>
    <body>
        <h1>Welcome to Our Newsletter!</h1>
        <p>This month's highlights:</p>
        <ul>
            <li>New product launch</li>
            <li>Customer spotlight</li>
            <li>Tips and tricks</li>
        </ul>
        <p><a href="https://example.com">Visit us</a></p>
    </body>
    </html>
    """
try alternative.add(TextPart("html", htmlText))

message.body = alternative
```

## Topics

### Related Types

- ``TextPart``
- ``MultipartAlternative``
- ``ContentType``

### Related Articles

- <doc:EncodingAndCharsets>
- <doc:MultipartMessages>
