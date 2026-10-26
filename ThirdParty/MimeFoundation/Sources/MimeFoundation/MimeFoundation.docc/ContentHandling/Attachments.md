# Attachments

Add file attachments to messages and extract them from parsed messages.

## Overview

Attachments are MIME parts with a Content-Disposition of "attachment". MimeFoundation makes it easy to add files to messages and extract attachments from received messages, handling encoding and MIME type detection automatically.

## Adding Attachments

The most common way to add attachments is using ``Multipart`` with a "mixed" subtype:

```swift
let multipart = try Multipart("mixed")

// Add the message body first
try multipart.add(TextPart("plain", "Please see the attached files."))

// Add an attachment from a file path
let attachment = try MimePart(fileName: "/path/to/document.pdf")
try multipart.add(attachment)

message.body = multipart
```

## Creating Attachments Manually

For more control, create ``MimePart`` instances directly:

```swift
let attachment = MimePart()

// Set content type
attachment.contentType.mediaType = "application"
attachment.contentType.mediaSubtype = "pdf"

// Set as attachment with filename
attachment.contentDisposition = try ContentDisposition(.attachment)
attachment.contentDisposition?.fileName = "report.pdf"

// Set the content
let fileData: [UInt8] = // ... file bytes
attachment.content = MimeContent(data: fileData)

// Set encoding (base64 is standard for binary files)
attachment.contentTransferEncoding = .base64
```

## Attachment from Data

Create attachments from in-memory data:

```swift
let imageData: [UInt8] = // ... PNG image bytes

let attachment = MimePart()
attachment.contentType.mediaType = "image"
attachment.contentType.mediaSubtype = "png"
attachment.contentDisposition = try ContentDisposition(.attachment)
attachment.contentDisposition?.fileName = "screenshot.png"
attachment.content = MimeContent(data: imageData)
attachment.contentTransferEncoding = .base64

try multipart.add(attachment)
```

## MIME Type Detection

The library can detect MIME types from file extensions:

```swift
// Automatic detection from filename
let part = try MimePart(fileName: "/path/to/photo.jpg")
// contentType is automatically set to image/jpeg

// Manual lookup
let mimeType = MimeTypeRegistry.shared.lookup(fileName: "document.docx")
// Returns "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
```

## Extracting Attachments

Use the ``MimeMessage/attachments`` property to get all attachments:

```swift
for attachment in message.attachments {
    guard let part = attachment as? MimePart else { continue }

    // Get attachment metadata
    let fileName = part.fileName ?? "unnamed"
    let mimeType = part.contentType.mimeType
    let size = part.content?.length ?? 0

    print("Found: \(fileName) (\(mimeType), \(size) bytes)")
}
```

## Saving Attachments

Read and save attachment content:

```swift
for attachment in message.attachments {
    guard let part = attachment as? MimePart,
          let content = part.content else { continue }

    let fileName = part.fileName ?? "attachment"

    // Read the decoded content
    let data = try content.read()

    // Save to file
    let path = "/downloads/\(fileName)"
    try Data(data).write(to: URL(fileURLWithPath: path))
}
```

## Inline Attachments

For attachments displayed inline (like images in HTML):

```swift
let image = MimePart()
image.contentType.mediaType = "image"
image.contentType.mediaSubtype = "png"
image.contentDisposition = try ContentDisposition(.inline)
image.contentId = "logo123"
image.content = MimeContent(data: imageData)

// Reference in HTML:
// <img src="cid:logo123">
```

## Using AttachmentCollection

The ``AttachmentCollection`` helper simplifies adding multiple attachments:

```swift
let attachments = AttachmentCollection()

// Add from file path
try attachments.add(fileName: "/path/to/doc1.pdf")
try attachments.add(fileName: "/path/to/doc2.pdf")

// Add from data with explicit MIME type
try attachments.add(data: imageBytes, mimeType: "image/jpeg", fileName: "photo.jpg")

// Get all parts
for part in attachments {
    try multipart.add(part)
}
```

## Attachment Metadata

Access metadata stored in Content-Disposition parameters:

```swift
if let disposition = part.contentDisposition {
    // Filename
    let fileName = disposition.fileName

    // File dates (if provided)
    let created = disposition.creationDate
    let modified = disposition.modificationDate
    let read = disposition.readDate

    // File size (if provided)
    let size = disposition.size
}
```

## Setting Attachment Metadata

```swift
let attachment = MimePart()
attachment.contentDisposition = try ContentDisposition(.attachment)
attachment.contentDisposition?.fileName = "report.pdf"
attachment.contentDisposition?.creationDate = DateTimeOffset.now
attachment.contentDisposition?.modificationDate = DateTimeOffset.now
attachment.contentDisposition?.size = 12345
```

## Filtering Attachments

Filter attachments by type:

```swift
// Get only PDF attachments
let pdfs = message.attachments.compactMap { $0 as? MimePart }
    .filter { $0.contentType.mimeType == "application/pdf" }

// Get only images
let images = message.attachments.compactMap { $0 as? MimePart }
    .filter { $0.contentType.mediaType == "image" }
```

## Large Attachments

For large files, stream content rather than loading into memory:

```swift
guard let part = attachment as? MimePart,
      let content = part.content else { return }

// Stream to file
let outputPath = "/downloads/large-file.zip"
let outputStream = try FileOutputStream(path: outputPath)
try content.decode(to: outputStream)
```

## Attachment Security

Be cautious with attachment filenames from untrusted sources:

```swift
// Sanitize filename to prevent path traversal
let unsafeFileName = part.fileName ?? "attachment"
let safeFileName = URL(fileURLWithPath: unsafeFileName).lastPathComponent

// Validate extension
let allowedExtensions = ["pdf", "doc", "docx", "txt"]
let ext = URL(fileURLWithPath: safeFileName).pathExtension.lowercased()
guard allowedExtensions.contains(ext) else {
    print("Blocked: \(safeFileName)")
    continue
}
```

## Complete Example

Creating a message with multiple attachments:

```swift
let message = MimeMessage()
message.from.add(MailboxAddress(address: "sender@example.com"))
message.to.add(MailboxAddress(address: "recipient@example.com"))
message.subject = "Documents for Review"

let multipart = try Multipart("mixed")

// Add body
try multipart.add(TextPart("plain", """
    Hi,

    Please review the attached documents:
    - Q4 Report (PDF)
    - Budget Spreadsheet (Excel)

    Best regards
    """))

// Add PDF attachment
let pdfPart = try MimePart(fileName: "/documents/q4-report.pdf")
try multipart.add(pdfPart)

// Add Excel attachment
let excelPart = try MimePart(fileName: "/documents/budget.xlsx")
try multipart.add(excelPart)

message.body = multipart

// Prepare for sending
try message.prepare(constraint: .sevenBit)
```

## Topics

### Related Types

- ``MimePart``
- ``ContentDisposition``
- ``MimeContent``
- ``AttachmentCollection``

### Related Articles

- <doc:MultipartMessages>
- <doc:StreamProcessing>
