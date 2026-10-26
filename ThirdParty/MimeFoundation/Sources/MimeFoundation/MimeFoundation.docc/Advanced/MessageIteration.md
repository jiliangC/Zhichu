# Message Iteration

Traverse and process MIME message structures.

## Overview

MIME messages can have complex nested structures with multipart containers, embedded messages, and various content types. MimeFoundation provides multiple ways to iterate through message parts, from simple enumeration to sophisticated tree traversal.

## Message Structure

A typical message structure might look like:

```
MimeMessage
└── Multipart (mixed)
    ├── Multipart (alternative)
    │   ├── TextPart (plain)
    │   └── Multipart (related)
    │       ├── TextPart (html)
    │       └── MimePart (image)
    └── MimePart (attachment)
```

## Using MimeIterator

``MimeIterator`` provides depth-first traversal:

```swift
let iterator = MimeIterator(message)

while iterator.moveNext() {
    let entity = iterator.current!

    print("Path: \(iterator.pathSpecifier)")  // e.g., "1.2.1"
    print("Depth: \(iterator.depth)")
    print("Type: \(entity.contentType)")

    if let parent = iterator.parent {
        print("Parent: \(parent.contentType)")
    }
}
```

### Path Specifier

The path specifier follows IMAP MIME-Part syntax:

- `"1"` - First part
- `"1.2"` - Second child of first part
- `"1.2.1"` - First child of second child of first part

```swift
// Navigate to a specific path
iterator.moveTo(pathSpecifier: "1.2.1")
let specificPart = iterator.current
```

### Iterator Properties

```swift
let iterator = MimeIterator(message)

while iterator.moveNext() {
    // Current entity
    let entity = iterator.current!

    // Nesting depth (0 = message body, 1 = first level child, etc.)
    let depth = iterator.depth

    // Parent entity (nil for message body)
    let parent = iterator.parent

    // Path specifier for IMAP
    let path = iterator.pathSpecifier
}
```

## Using the Visitor Pattern

Implement ``MimeVisitor`` for type-specific processing:

```swift
class MyVisitor: MimeVisitor {
    var textParts: [TextPart] = []
    var attachments: [MimePart] = []

    func visit(_ message: MimeMessage) {
        // Process message-level data
        print("Subject: \(message.subject ?? "none")")
    }

    func visit(_ entity: MimeEntity) {
        // Default handling for entities
    }

    func visit(_ textPart: TextPart) {
        textParts.append(textPart)
    }

    func visit(_ mimePart: MimePart) {
        if mimePart.isAttachment {
            attachments.append(mimePart)
        }
    }

    func visit(_ multipart: Multipart) {
        // Process multipart container
        print("Multipart with \(multipart.count) parts")
    }

    func visit(_ messagePart: MessagePart) {
        // Process embedded message
        if let embedded = messagePart.message {
            print("Embedded: \(embedded.subject ?? "none")")
        }
    }
}

// Use the visitor
let visitor = MyVisitor()
message.accept(visitor)
print("Found \(visitor.textParts.count) text parts")
print("Found \(visitor.attachments.count) attachments")
```

## Convenience Properties

### Body Parts

``MimeMessage/bodyParts`` iterates all MIME entities:

```swift
for part in message.bodyParts {
    print("Part: \(part.contentType)")
}
```

### Attachments

``MimeMessage/attachments`` filters to attachment parts:

```swift
for attachment in message.attachments {
    if let part = attachment as? MimePart {
        print("Attachment: \(part.fileName ?? "unnamed")")
    }
}
```

### Text Bodies

Quick access to text content:

```swift
// Plain text body
let plainText = message.textBody

// HTML body
let htmlBody = message.htmlBody
```

## Iterating Multipart Content

Direct iteration over multipart containers:

```swift
guard let multipart = message.body as? Multipart else { return }

for part in multipart {
    print("Part type: \(part.contentType)")
}

// With index
for (index, part) in multipart.enumerated() {
    print("Part \(index): \(part.contentType)")
}

// By index
let firstPart = multipart[0]
```

## Finding Specific Parts

### By Content Type

```swift
func findPartsByType(_ entity: MimeEntity?, type: String) -> [MimeEntity] {
    var results: [MimeEntity] = []

    guard let entity = entity else { return results }

    if entity.contentType.mimeType == type {
        results.append(entity)
    }

    if let multipart = entity as? Multipart {
        for part in multipart {
            results.append(contentsOf: findPartsByType(part, type: type))
        }
    }

    return results
}

// Find all HTML parts
let htmlParts = findPartsByType(message.body, type: "text/html")
```

### By Content-ID

```swift
func findPartById(_ entity: MimeEntity?, id: String) -> MimeEntity? {
    guard let entity = entity else { return nil }

    if entity.contentId == id {
        return entity
    }

    if let multipart = entity as? Multipart {
        for part in multipart {
            if let found = findPartById(part, id: id) {
                return found
            }
        }
    }

    return nil
}

// Find part referenced by cid:logo123
let logoPart = findPartById(message.body, id: "logo123")
```

## Processing Embedded Messages

Handle message/rfc822 parts:

```swift
func processAllMessages(_ message: MimeMessage) {
    print("Processing: \(message.subject ?? "no subject")")

    let iterator = MimeIterator(message)
    while iterator.moveNext() {
        if let messagePart = iterator.current as? MessagePart,
           let embedded = messagePart.message {
            // Recursively process embedded message
            processAllMessages(embedded)
        }
    }
}
```

## Practical Examples

### Extract All Text Content

```swift
func extractAllText(_ message: MimeMessage) -> String {
    var text = ""

    let iterator = MimeIterator(message)
    while iterator.moveNext() {
        if let textPart = iterator.current as? TextPart {
            text += textPart.text + "\n"
        }
    }

    return text
}
```

### List Message Structure

```swift
func printStructure(_ message: MimeMessage) {
    let iterator = MimeIterator(message)

    while iterator.moveNext() {
        let indent = String(repeating: "  ", count: iterator.depth)
        let type = iterator.current!.contentType.mimeType
        let path = iterator.pathSpecifier

        print("\(indent)[\(path)] \(type)")
    }
}

// Output:
// [1] multipart/mixed
//   [1.1] multipart/alternative
//     [1.1.1] text/plain
//     [1.1.2] text/html
//   [1.2] application/pdf
```

### Calculate Total Attachment Size

```swift
func totalAttachmentSize(_ message: MimeMessage) -> Int64 {
    var total: Int64 = 0

    for attachment in message.attachments {
        if let part = attachment as? MimePart,
           let content = part.content {
            total += content.length
        }
    }

    return total
}
```

### Find Best Text Representation

```swift
func getBestTextBody(_ message: MimeMessage) -> String? {
    // Prefer HTML
    if let html = message.htmlBody {
        return html
    }

    // Fall back to plain text
    if let plain = message.textBody {
        return plain
    }

    // Search manually
    let iterator = MimeIterator(message)
    while iterator.moveNext() {
        if let text = iterator.current as? TextPart {
            return text.text
        }
    }

    return nil
}
```

## Topics

### Related Types

- ``MimeIterator``
- ``MimeVisitor``
- ``Multipart``
- ``MessagePart``

### Related Articles

- <doc:ParsingMessages>
- <doc:MultipartMessages>
