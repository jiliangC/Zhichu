# QuickStart

Get up and running with MimeFoundation in minutes.

## Overview

This guide walks you through the most common tasks when working with MIME messages: creating messages, adding content and attachments, and parsing existing messages.

## Creating Your First Message

The simplest way to create an email message is to instantiate ``MimeMessage`` and set its properties:

```swift
import MimeFoundation

let message = MimeMessage()

// Set the sender
message.from.add(MailboxAddress(name: "Alice Smith", address: "alice@example.com"))

// Set recipients
message.to.add(MailboxAddress(name: "Bob Jones", address: "bob@example.com"))
message.cc.add(MailboxAddress(address: "carol@example.com"))

// Set the subject
message.subject = "Meeting Tomorrow"

// Set a plain text body
message.body = TextPart("plain", "Don't forget about our meeting tomorrow at 10 AM.")
```

## Adding an HTML Body

For HTML emails, use ``TextPart`` with the `"html"` subtype:

```swift
message.body = TextPart("html", """
    <html>
    <body>
        <h1>Meeting Tomorrow</h1>
        <p>Don't forget about our meeting tomorrow at <strong>10 AM</strong>.</p>
    </body>
    </html>
    """)
```

## Creating a Multipart Message

To include both plain text and HTML alternatives, use ``MultipartAlternative``:

```swift
let alternative = try MultipartAlternative()
try alternative.add(TextPart("plain", "Don't forget about our meeting tomorrow at 10 AM."))
try alternative.add(TextPart("html", "<h1>Meeting Tomorrow</h1><p>Don't forget!</p>"))
message.body = alternative
```

## Adding Attachments

Use ``Multipart`` with a "mixed" subtype to combine body content with attachments:

```swift
let multipart = try Multipart("mixed")

// Add the body
try multipart.add(TextPart("plain", "Please see the attached document."))

// Add an attachment from a file path
let attachment = try MimePart(fileName: "/path/to/document.pdf")
try multipart.add(attachment)

message.body = multipart
```

## Serializing a Message

Write a message to a stream or get it as bytes:

```swift
// Write to a memory stream
let stream = MemoryStream()
try message.writeTo(stream)

// Get the raw bytes
let bytes = stream.toArray()

// Convert to string (for debugging)
let rawMessage = String(data: Data(bytes), encoding: .utf8)
```

## Parsing a Message

Load a message from raw bytes or a stream:

```swift
// From a stream
let inputStream = MemoryStream(data: messageBytes)
let message = try MimeMessage.load(inputStream)

// Access message properties
print("From: \(message.from)")
print("Subject: \(message.subject ?? "No subject")")
print("Date: \(message.date?.description ?? "Unknown")")

// Get the text body
if let textBody = message.textBody {
    print("Body: \(textBody)")
}
```

## Iterating Over Attachments

The ``MimeMessage/attachments`` property provides easy access to all attachments:

```swift
for attachment in message.attachments {
    if let part = attachment as? MimePart {
        let fileName = part.fileName ?? "unnamed"
        print("Attachment: \(fileName)")

        // Get the content
        if let content = part.content {
            let data = try content.read()
            // Process the attachment data...
        }
    }
}
```

## Next Steps

Now that you understand the basics, explore these topics for more advanced usage:

- <doc:CreatingMessages> - Detailed guide to message creation
- <doc:ParsingMessages> - In-depth parsing options
- <doc:Attachments> - Working with file attachments
- <doc:SMIMEOverview> - Signing and encrypting messages

## Topics

### Related Articles

- <doc:CreatingMessages>
- <doc:ParsingMessages>
