# Parsing Messages

Load and parse MIME messages from various sources.

## Overview

MimeFoundation includes a robust parser that handles real-world email messages, including malformed ones. The parser supports RFC 2822/5322 message format and can handle messages from virtually any email source.

## Loading a Message

The simplest way to parse a message is using ``MimeMessage/load(_:options:)``:

```swift
// From a memory stream
let data: [UInt8] = // ... raw message bytes
let stream = MemoryStream(data: data)
let message = try MimeMessage.load(stream)
```

## Using MimeParser

For more control, use ``MimeParser`` directly:

```swift
let parser = try MimeParser(stream)

// Parse a single message
let message = try parser.parseMessage()

// Parse multiple messages (for mbox files)
while let message = try parser.parseMessage() {
    // Process each message
    print(message.subject ?? "No subject")
}
```

## Parser Options

Configure parsing behavior with ``ParserOptions``:

```swift
var options = ParserOptions()

// Lenient parsing for malformed addresses
options.addressParserComplianceMode = .loose

// Allow addresses without domain (local addresses)
options.allowAddressesWithoutDomain = true

// Set maximum MIME nesting depth (security protection)
options.maxMimeDepth = 100

// Use specific charset for unknown encodings
options.charsetEncoding = .utf8

let message = try MimeMessage.load(stream, options: options)
```

### Compliance Modes

The ``RfcComplianceMode`` enum controls parsing strictness:

- **`.strict`**: Enforce RFC compliance; reject malformed content
- **`.loose`**: Accept malformed content when possible (recommended for reading external messages)

```swift
options.addressParserComplianceMode = .loose
options.parameterComplianceMode = .loose
options.rfc2047ComplianceMode = .loose
```

## Accessing Message Properties

After parsing, access message data through properties:

```swift
// Sender information
let from = message.from.first  // First sender
let sender = message.sender    // Actual sender (if different)

// Recipients
for recipient in message.to {
    print("To: \(recipient)")
}

// Subject and date
let subject = message.subject ?? "No subject"
let date = message.date ?? DateTimeOffset.now

// Message ID and threading
let messageId = message.messageId
let inReplyTo = message.inReplyTo
let references = message.references
```

## Accessing the Body

Get the message body content:

```swift
// Quick access to text content
if let plainText = message.textBody {
    print("Plain text: \(plainText)")
}

if let htmlText = message.htmlBody {
    print("HTML: \(htmlText)")
}

// Direct body access
if let body = message.body {
    switch body {
    case let textPart as TextPart:
        print("Simple text message")
    case let multipart as Multipart:
        print("Multipart message with \(multipart.count) parts")
    case let messagePart as MessagePart:
        print("Embedded message")
    default:
        print("Other MIME part")
    }
}
```

## Iterating Over Parts

Use ``MimeIterator`` to traverse the message structure:

```swift
let iterator = MimeIterator(message)

while iterator.moveNext() {
    let entity = iterator.current!
    print("Path: \(iterator.pathSpecifier)")
    print("Depth: \(iterator.depth)")
    print("Type: \(entity.contentType)")
}
```

## Finding Attachments

The ``MimeMessage/attachments`` property returns all attachment parts:

```swift
for attachment in message.attachments {
    guard let part = attachment as? MimePart else { continue }

    let fileName = part.fileName ?? "unknown"
    let contentType = part.contentType.mimeType

    print("Attachment: \(fileName) (\(contentType))")

    // Read attachment content
    if let content = part.content {
        let data = try content.read()
        // Process attachment data...
    }
}
```

## Handling Embedded Messages

Messages can contain other messages (forwarded mail, delivery reports):

```swift
func processMessage(_ message: MimeMessage) {
    if let messagePart = message.body as? MessagePart {
        if let embeddedMessage = messagePart.message {
            print("Embedded message subject: \(embeddedMessage.subject ?? "none")")
            // Recursively process embedded message
            processMessage(embeddedMessage)
        }
    }
}
```

## Parsing Delivery Status Notifications

Handle bounce messages and delivery reports:

```swift
if let report = message.body as? MultipartReport {
    for part in report {
        if let status = part as? MessageDeliveryStatus {
            // Access delivery status fields
            for group in status.statusGroups {
                for field in group {
                    print("\(field.field): \(field.value)")
                }
            }
        }
    }
}
```

## Error Handling

The parser throws descriptive errors for malformed content:

```swift
do {
    let message = try MimeMessage.load(stream)
} catch let error as ParseException {
    print("Parse error at position \(error.tokenIndex): \(error.message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Parsing Headers Only

For efficiency, you can parse only the headers:

```swift
let (headers, bodyOffset) = try MimeMessage.parseHeaders(from: data)

// Access headers without parsing body
if let subject = headers[.subject] {
    print("Subject: \(subject.value)")
}

// Parse body later if needed
// ...
```

## Memory-Efficient Parsing

For large messages, content is loaded lazily:

```swift
// Message loads but content isn't decoded until accessed
let message = try MimeMessage.load(stream)

// Content is decoded here (on demand)
if let part = message.body as? MimePart,
   let content = part.content {
    let data = try content.read()
}
```

## Topics

### Related Types

- ``MimeParser``
- ``ParserOptions``
- ``RfcComplianceMode``
- ``MimeIterator``

### Related Articles

- <doc:WorkingWithHeaders>
- <doc:MessageIteration>
