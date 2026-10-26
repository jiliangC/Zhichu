# Multipart Messages

Build complex message structures with multiple body parts.

## Overview

MIME multipart messages contain multiple body parts within a single message. MimeFoundation provides ``Multipart`` and its specialized subclasses to create properly structured multipart content for emails with attachments, alternative formats, related content, and more.

## Multipart Subtypes

Different multipart subtypes serve different purposes:

| Subtype | Class | Purpose |
|---------|-------|---------|
| mixed | ``Multipart`` | Combine different content types (body + attachments) |
| alternative | ``MultipartAlternative`` | Same content in different formats (plain + HTML) |
| related | ``MultipartRelated`` | Content with referenced resources (HTML + images) |
| signed | ``MultipartSigned`` | Digitally signed content |
| encrypted | ``Multipart`` | Encrypted content |
| report | ``MultipartReport`` | Delivery/disposition notifications |

## Creating Multipart Content

### Multipart/Mixed (Body + Attachments)

Use multipart/mixed when combining different types of content:

```swift
let multipart = try Multipart("mixed")

// Add the message body
try multipart.add(TextPart("plain", "Please see the attached file."))

// Add an attachment
let attachment = try MimePart(fileName: "/path/to/document.pdf")
try multipart.add(attachment)

message.body = multipart
```

### Multipart/Alternative (Multiple Formats)

Use when providing the same content in different formats:

```swift
let alternative = try MultipartAlternative()

// Plain text (fallback) - add first
try alternative.add(TextPart("plain", "Welcome to our newsletter!"))

// HTML (preferred) - add last
try alternative.add(TextPart("html", "<h1>Welcome to our newsletter!</h1>"))

message.body = alternative
```

> Important: In multipart/alternative, parts are ordered from least to most preferred. Email clients display the last format they support.

### Multipart/Related (Referenced Content)

Use when content references other parts (like images in HTML):

```swift
let related = try MultipartRelated()

// Add HTML that references an image
let html = TextPart("html", """
    <html>
    <body>
        <img src="cid:logo123">
        <p>Welcome!</p>
    </body>
    </html>
    """)
try related.add(html)

// Add the referenced image
let image = MimePart()
image.contentType.mediaType = "image"
image.contentType.mediaSubtype = "png"
image.contentId = "logo123"  // Matches the cid: reference
image.contentDisposition = try ContentDisposition(.inline)
image.content = MimeContent(data: imageData)
try related.add(image)

message.body = related
```

## Nesting Multipart Structures

Complex messages often nest multipart structures:

```swift
// Message with body + attachments, where body has text/HTML alternatives

// Outer: multipart/mixed (body + attachments)
let mixed = try Multipart("mixed")

// Inner: multipart/alternative (text + HTML)
let alternative = try MultipartAlternative()
try alternative.add(TextPart("plain", "See attachment."))
try alternative.add(TextPart("html", "<p>See attachment.</p>"))

// Add alternative as the body
try mixed.add(alternative)

// Add attachment
let attachment = try MimePart(fileName: "/path/to/file.pdf")
try mixed.add(attachment)

message.body = mixed
```

### HTML with Embedded Images + Attachments

```swift
// Structure: mixed [ related [ alternative [ plain, html ], image ], attachment ]

let mixed = try Multipart("mixed")

let related = try MultipartRelated()

let alternative = try MultipartAlternative()
try alternative.add(TextPart("plain", "Company Logo"))
try alternative.add(TextPart("html", "<img src='cid:logo'>"))
try related.add(alternative)

let logo = MimePart()
logo.contentId = "logo"
logo.content = MimeContent(data: logoData)
try related.add(logo)

try mixed.add(related)

let attachment = try MimePart(fileName: "report.pdf")
try mixed.add(attachment)

message.body = mixed
```

## Working with Parsed Multipart

Access parts of a parsed multipart message:

```swift
guard let multipart = message.body as? Multipart else { return }

// Iterate over parts
for part in multipart {
    print("Part type: \(part.contentType)")
}

// Access by index
let firstPart = multipart[0]

// Get count
let partCount = multipart.count
```

## Multipart as Collection

``Multipart`` conforms to Swift collection protocols:

```swift
let multipart = try Multipart("mixed")

// Add parts
try multipart.add(part1)
try multipart.add(part2)

// Collection operations
print("Part count: \(multipart.count)")
print("Is empty: \(multipart.isEmpty)")

// Iterate
for (index, part) in multipart.enumerated() {
    print("Part \(index): \(part.contentType)")
}

// Access by index
let first = multipart[0]
```

## Boundary Management

Each multipart has a boundary string that separates parts:

```swift
let multipart = try Multipart("mixed")

// Boundary is auto-generated
print("Boundary: \(multipart.boundary ?? "none")")

// Or set explicitly
multipart.boundary = "----=_Part_12345"
```

The boundary appears in the serialized message like:
```
Content-Type: multipart/mixed; boundary="----=_Part_12345"

------=_Part_12345
Content-Type: text/plain

Hello
------=_Part_12345
Content-Type: application/pdf

[attachment data]
------=_Part_12345--
```

## Preamble and Epilogue

Multipart messages can include text before the first boundary (preamble) and after the last boundary (epilogue):

```swift
let multipart = try Multipart("mixed")

// Set preamble (shown to non-MIME readers)
multipart.preamble = "This is a MIME message. If you see this, your email client doesn't support MIME."

// Epilogue is rarely used
multipart.epilogue = ""
```

## Modifying Multipart Content

```swift
// Insert at specific position
try multipart.insert(newPart, at: 0)

// Remove a part
multipart.remove(at: 1)

// Clear all parts
multipart.removeAll()

// Replace a part
multipart[0] = replacementPart
```

## Finding Parts by Type

```swift
// Find all text parts
let textParts = multipart.compactMap { $0 as? TextPart }

// Find HTML part
let htmlPart = multipart.first { part in
    part.contentType.mimeType == "text/html"
}

// Find all attachments
let attachments = multipart.filter { part in
    part.contentDisposition?.isAttachment == true
}
```

## Delivery Status Reports

``MultipartReport`` handles delivery status notifications:

```swift
if let report = message.body as? MultipartReport {
    print("Report type: \(report.reportType ?? "unknown")")

    for part in report {
        if let status = part as? MessageDeliveryStatus {
            // Process delivery status
        } else if let original = part as? MessagePart {
            // Original message headers
        }
    }
}
```

## Complete Example

Building a professional email with all features:

```swift
let message = MimeMessage()
message.from.add(MailboxAddress(name: "Newsletter", address: "news@company.com"))
message.to.add(MailboxAddress(address: "subscriber@example.com"))
message.subject = "Monthly Newsletter"

// Build structure: mixed [ related [ alternative [ plain, html ], logo ], attachment ]
let mixed = try Multipart("mixed")

let related = try MultipartRelated()

let alternative = try MultipartAlternative()

// Plain text fallback
try alternative.add(TextPart("plain", """
    Monthly Newsletter

    Welcome to this month's edition!
    See attached PDF for full details.
    """))

// HTML with embedded logo
try alternative.add(TextPart("html", """
    <html>
    <body>
        <img src="cid:header-logo" alt="Company">
        <h1>Monthly Newsletter</h1>
        <p>Welcome to this month's edition!</p>
        <p>See attached PDF for full details.</p>
    </body>
    </html>
    """))

try related.add(alternative)

// Embedded logo image
let logo = MimePart()
logo.contentType.mediaType = "image"
logo.contentType.mediaSubtype = "png"
logo.contentId = "header-logo"
logo.contentDisposition = try ContentDisposition(.inline)
logo.content = MimeContent(data: logoImageData)
try related.add(logo)

try mixed.add(related)

// PDF attachment
let pdf = try MimePart(fileName: "/newsletters/june-2024.pdf")
try mixed.add(pdf)

message.body = mixed
```

## Topics

### Related Types

- ``Multipart``
- ``MultipartAlternative``
- ``MultipartRelated``
- ``MultipartReport``

### Related Articles

- <doc:TextContent>
- <doc:Attachments>
- <doc:MessageIteration>
