# Creating Messages

Build email messages programmatically with full control over structure and content.

## Overview

MimeFoundation provides a rich API for creating MIME messages. Whether you need a simple plain-text email or a complex multipart message with attachments and embedded images, you can build it step by step using the library's intuitive types.

## Basic Message Structure

Every email message starts with a ``MimeMessage`` instance:

```swift
let message = MimeMessage()
```

A complete message typically includes:

- **Sender information**: Who the message is from
- **Recipients**: Who receives the message
- **Subject**: The message subject line
- **Body**: The message content

## Setting Sender Information

Use the ``MimeMessage/from`` property to specify the sender:

```swift
// Simple address
message.from.add(MailboxAddress(address: "alice@example.com"))

// With display name
message.from.add(MailboxAddress(name: "Alice Smith", address: "alice@example.com"))

// Multiple senders (rare, but supported)
message.from.add(MailboxAddress(name: "Alice", address: "alice@example.com"))
message.from.add(MailboxAddress(name: "Bob", address: "bob@example.com"))
message.sender = MailboxAddress(address: "alice@example.com") // Actual sender
```

## Adding Recipients

Messages support multiple recipient types through separate address lists:

```swift
// Primary recipients (To)
message.to.add(MailboxAddress(name: "Bob Jones", address: "bob@example.com"))
message.to.add(MailboxAddress(address: "carol@example.com"))

// Carbon copy recipients (Cc)
message.cc.add(MailboxAddress(address: "dave@example.com"))

// Blind carbon copy recipients (Bcc)
// Note: Bcc recipients are stripped when the message is serialized
message.bcc.add(MailboxAddress(address: "eve@example.com"))
```

## Setting Message Metadata

Configure additional message properties:

```swift
// Subject line
message.subject = "Quarterly Report"

// Date (defaults to current time if not set)
message.date = DateTimeOffset.now

// Message ID (auto-generated if not set)
message.messageId = MimeUtils.generateMessageId(domain: "example.com")

// Reply-to address (if different from sender)
message.replyTo.add(MailboxAddress(address: "support@example.com"))

// Threading information
message.inReplyTo = "<original-message-id@example.com>"
message.references.add("<original-message-id@example.com>")
```

## Message Priority

Set the importance level of your message:

```swift
// High priority
message.importance = .high
message.priority = .urgent

// Normal priority (default)
message.importance = .normal

// Low priority
message.importance = .low
message.priority = .nonUrgent
```

## Plain Text Body

For simple text emails, assign a ``TextPart`` directly to the body:

```swift
message.body = TextPart("plain", "Hello, this is the message content.")
```

You can also specify character encoding:

```swift
let textPart = TextPart("plain", "Hello, こんにちは")
textPart.contentType.charset = "utf-8"
message.body = textPart
```

## HTML Body

Create HTML emails using ``TextPart`` with the "html" subtype:

```swift
message.body = TextPart("html", """
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; }
            .highlight { color: #0066cc; }
        </style>
    </head>
    <body>
        <h1>Welcome!</h1>
        <p>This is an <span class="highlight">HTML email</span>.</p>
    </body>
    </html>
    """)
```

## Multipart Alternative (Plain + HTML)

Best practice is to include both plain text and HTML versions:

```swift
let alternative = try MultipartAlternative()

// Add plain text first (fallback)
try alternative.add(TextPart("plain", "Welcome! This is an HTML email."))

// Add HTML version (preferred)
try alternative.add(TextPart("html", "<h1>Welcome!</h1><p>This is an HTML email.</p>"))

message.body = alternative
```

> Important: In multipart/alternative, parts are ordered from least to most preferred. Email clients display the last format they support.

## Adding Custom Headers

Add headers not covered by dedicated properties:

```swift
// Using HeaderId enum
try message.headers.set(id: .organization, value: "Acme Corp")

// Using string field name
try message.headers.set(field: "X-Custom-Header", value: "custom value")

// Add multiple values for the same header
try message.headers.add(field: "X-Tag", value: "important")
try message.headers.add(field: "X-Tag", value: "review")
```

## Serializing the Message

Once your message is complete, serialize it for sending:

```swift
// To a stream
let stream = MemoryStream()
try message.writeTo(stream)

// With custom format options
var options = FormatOptions()
options.newLineFormat = .dos  // CRLF line endings
try message.writeTo(stream, options: options)

// Prepare for sending (ensures proper encoding)
try message.prepare(constraint: .sevenBit)
```

## Complete Example

Here's a full example creating a professional email:

```swift
let message = MimeMessage()

// Sender and recipients
message.from.add(MailboxAddress(name: "Sales Team", address: "sales@company.com"))
message.to.add(MailboxAddress(name: "John Customer", address: "john@customer.com"))
message.replyTo.add(MailboxAddress(address: "support@company.com"))

// Metadata
message.subject = "Your Order Confirmation #12345"
message.date = DateTimeOffset.now
message.importance = .normal

// Custom headers
try message.headers.set(field: "X-Order-ID", value: "12345")

// Body with both text and HTML
let alternative = try MultipartAlternative()

try alternative.add(TextPart("plain", """
    Thank you for your order!

    Order Number: 12345
    Total: $99.99

    Questions? Reply to this email.
    """))

try alternative.add(TextPart("html", """
    <html>
    <body>
        <h1>Thank you for your order!</h1>
        <table>
            <tr><td>Order Number:</td><td>12345</td></tr>
            <tr><td>Total:</td><td>$99.99</td></tr>
        </table>
        <p>Questions? Reply to this email.</p>
    </body>
    </html>
    """))

message.body = alternative

// Serialize
let output = MemoryStream()
try message.writeTo(output)
```

## Topics

### Related Types

- ``MimeMessage``
- ``TextPart``
- ``Multipart``
- ``MultipartAlternative``
- ``MailboxAddress``

### Related Articles

- <doc:Attachments>
- <doc:MultipartMessages>
- <doc:WorkingWithHeaders>
