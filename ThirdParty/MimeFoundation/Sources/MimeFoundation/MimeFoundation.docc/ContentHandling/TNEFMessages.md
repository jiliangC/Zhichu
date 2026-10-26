# TNEF Messages

Work with Microsoft Transport Neutral Encapsulation Format (TNEF) attachments commonly found in emails from Microsoft Outlook.

## Overview

TNEF (Transport Neutral Encapsulation Format) is a proprietary email attachment format used by Microsoft Outlook and Exchange Server. When Outlook sends rich-formatted emails or attachments to non-Microsoft clients, it often encapsulates the data in a TNEF attachment, typically named `winmail.dat`.

MimeFoundation provides comprehensive support for parsing TNEF attachments and extracting their contents, including:

- **Message Properties**: Subject, date, importance, priority, and message IDs
- **Rich Text Content**: RTF, HTML, and plain text body alternatives
- **Attachments**: File attachments with full metadata (filename, dates, size)
- **Recipients**: To, CC, and BCC recipient information
- **Embedded Messages**: Nested TNEF messages within attachments

## Detecting TNEF Parts

TNEF parts are automatically recognized when parsing messages with content types `application/vnd.ms-tnef` or `application/ms-tnef`:

```swift
let message = try MimeMessage.load(stream)

for part in message.bodyParts {
    if let tnefPart = part as? TnefPart {
        print("Found TNEF attachment!")
        // Process the TNEF part
    }
}
```

## Converting TNEF to a Message

The most common use case is converting a TNEF attachment to a standard ``MimeMessage``:

```swift
guard let tnefPart = message.bodyParts.first(where: { $0 is TnefPart }) as? TnefPart else {
    return
}

// Convert to a standard MIME message
let extractedMessage = try tnefPart.convertToMessage()

// Access the extracted content
print("Subject: \(extractedMessage.subject ?? "")")
print("From: \(extractedMessage.from)")

if let body = extractedMessage.body as? TextPart {
    print("Body: \(body.text ?? "")")
}
```

## Extracting Attachments

Extract just the attachments from a TNEF part without converting the entire message:

```swift
let attachments = try tnefPart.extractAttachments()

for attachment in attachments {
    if let mimePart = attachment as? MimePart {
        let fileName = mimePart.fileName ?? "unknown"
        let mimeType = mimePart.contentType.mimeType
        print("Attachment: \(fileName) (\(mimeType))")

        // Save the attachment
        if let content = mimePart.content {
            let data = try content.read()
            try Data(data).write(to: URL(fileURLWithPath: "/downloads/\(fileName)"))
        }
    } else if let textPart = attachment as? TextPart {
        // Body content (HTML, RTF, or plain text)
        print("Body part: \(textPart.contentType.mimeType)")
    }
}
```

## Working with TNEF Content Types

The extracted message may contain various body formats:

```swift
let extracted = try tnefPart.convertToMessage()

if let multipart = extracted.body as? Multipart {
    for part in multipart {
        if let text = part as? TextPart {
            switch text.contentType.mediaSubtype.lowercased() {
            case "rtf":
                print("RTF content available")
            case "html":
                print("HTML content: \(text.text ?? "")")
            case "plain":
                print("Plain text: \(text.text ?? "")")
            default:
                break
            }
        } else if let mimePart = part as? MimePart {
            print("File attachment: \(mimePart.fileName ?? "unnamed")")
        }
    }
}
```

## Handling RTF Content

TNEF often contains compressed RTF content. MimeFoundation automatically decompresses it:

```swift
let extracted = try tnefPart.convertToMessage()

// Find RTF body part
if let multipart = extracted.body as? Multipart,
   let rtf = multipart.first(where: { ($0 as? TextPart)?.contentType.mediaSubtype == "rtf" }) as? TextPart {
    let rtfContent = rtf.text
    // Process RTF content (you may need an RTF-to-HTML converter for display)
}
```

## Attachment Metadata

TNEF preserves rich metadata for attachments:

```swift
for attachment in try tnefPart.extractAttachments() {
    guard let part = attachment as? MimePart else { continue }

    // Filename
    let fileName = part.fileName

    // Content disposition metadata
    if let disposition = part.contentDisposition {
        let creationDate = disposition.creationDate
        let modificationDate = disposition.modificationDate
        let fileSize = disposition.size

        print("File: \(fileName ?? "unnamed")")
        print("  Created: \(creationDate?.description ?? "unknown")")
        print("  Modified: \(modificationDate?.description ?? "unknown")")
        print("  Size: \(fileSize ?? 0) bytes")
    }

    // Content ID (for inline attachments)
    if let contentId = part.contentId {
        print("  Content-ID: \(contentId)")
    }

    // Content location (for linked content)
    if let location = part.contentLocation {
        print("  Location: \(location)")
    }
}
```

## Embedded TNEF Messages

TNEF can contain embedded messages (nested TNEF):

```swift
for attachment in try tnefPart.extractAttachments() {
    if let nestedTnef = attachment as? TnefPart {
        // Recursively process nested TNEF
        let nestedMessage = try nestedTnef.convertToMessage()
        print("Nested message subject: \(nestedMessage.subject ?? "")")
    }
}
```

## Low-Level TNEF Reading

For advanced use cases, access the TNEF data directly using ``TnefReader``:

```swift
guard let content = tnefPart.content else { return }

let reader = TnefReader(
    inputStream: try content.open(),
    defaultMessageCodepage: 0,
    complianceMode: .loose
)

while try reader.readNextAttribute() {
    print("Attribute: \(reader.attributeTag)")
    print("Level: \(reader.attributeLevel)")

    if reader.attributeTag == .mapiProperties {
        let propertyReader = reader.tnefPropertyReader!
        while try propertyReader.readNextProperty() {
            print("  Property: \(propertyReader.propertyTag.id)")
        }
    }
}
```

## Compliance Modes

Control how strictly TNEF data is validated:

```swift
// Strict mode - fails on any invalid data
let strictReader = TnefReader(
    inputStream: stream,
    defaultMessageCodepage: 0,
    complianceMode: .strict
)

// Loose mode - tolerates common issues (default)
let looseReader = TnefReader(
    inputStream: stream,
    defaultMessageCodepage: 0,
    complianceMode: .loose
)

// Permissive mode - maximum tolerance
let permissiveReader = TnefReader(
    inputStream: stream,
    defaultMessageCodepage: 0,
    complianceMode: .veryLoose
)
```

## Charset Handling

TNEF HTML content may specify its charset in a meta tag. MimeFoundation automatically detects and uses the correct encoding:

```swift
let extracted = try tnefPart.convertToMessage()

if let html = extracted.body as? TextPart, html.isHtml {
    // Charset is automatically detected from HTML meta tags
    print("Charset: \(html.contentType.charset ?? "default")")
    print("HTML: \(html.text ?? "")")
}
```

## Complete Example

Processing all TNEF attachments in an email:

```swift
let message = try MimeMessage.load(stream)

// Find and process all TNEF parts
for part in message.bodyParts {
    guard let tnefPart = part as? TnefPart else { continue }

    do {
        // Convert to standard message
        let extracted = try tnefPart.convertToMessage()

        print("=== TNEF Content ===")
        print("Subject: \(extracted.subject ?? "(none)")")
        print("Date: \(extracted.date?.description ?? "(none)")")

        // Process body
        if let body = extracted.body {
            processBody(body)
        }

        // Extract and save attachments
        let attachments = try tnefPart.extractAttachments()
        for (index, attachment) in attachments.enumerated() {
            if let mimePart = attachment as? MimePart,
               let content = mimePart.content {
                let fileName = mimePart.fileName ?? "attachment-\(index)"
                let data = try content.read()
                try Data(data).write(to: URL(fileURLWithPath: "/downloads/\(fileName)"))
                print("Saved: \(fileName)")
            }
        }
    } catch {
        print("Failed to process TNEF: \(error)")
    }
}

func processBody(_ body: MimeEntity) {
    if let text = body as? TextPart {
        if text.isHtml {
            print("HTML body available")
        } else if text.contentType.mediaSubtype == "rtf" {
            print("RTF body available")
        } else {
            print("Plain text: \(text.text ?? "")")
        }
    } else if let multipart = body as? Multipart {
        for child in multipart {
            processBody(child)
        }
    }
}
```

## Topics

### Core Types

- ``TnefPart``
- ``TnefReader``
- ``TnefPropertyReader``

### Configuration

- ``TnefComplianceMode``
- ``TnefComplianceStatus``

### Property Types

- ``TnefPropertyId``
- ``TnefPropertyTag``
- ``TnefPropertyType``
- ``TnefAttributeTag``
- ``TnefAttributeLevel``

### Related Articles

- <doc:Attachments>
- <doc:MultipartMessages>
- <doc:EncodingAndCharsets>
