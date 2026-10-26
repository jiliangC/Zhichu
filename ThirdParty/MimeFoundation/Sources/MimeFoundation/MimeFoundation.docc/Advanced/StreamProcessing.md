# Stream Processing

Work with MIME content efficiently using streams and filters.

## Overview

MimeFoundation uses a stream-based architecture for efficient processing of large messages. Rather than loading entire messages into memory, content can be processed incrementally through streams and filter chains.

## Stream Types

### MimeStream Protocol

The base protocol for all stream operations:

```swift
protocol MimeStream {
    func read(into buffer: inout [UInt8], offset: Int, count: Int) throws -> Int
    func write(_ buffer: [UInt8], offset: Int, count: Int) throws
    func seek(offset: Int64, origin: SeekOrigin) throws -> Int64
    var position: Int64 { get }
    var length: Int64 { get }
    var canRead: Bool { get }
    var canWrite: Bool { get }
    var canSeek: Bool { get }
}
```

### MemoryStream

In-memory byte buffer for small to medium content:

```swift
// Create empty
let stream = MemoryStream()

// Create with initial data
let stream = MemoryStream(data: [0x48, 0x65, 0x6C, 0x6C, 0x6F])

// Write data
try stream.write([0x01, 0x02, 0x03], offset: 0, count: 3)

// Read data
var buffer = [UInt8](repeating: 0, count: 100)
let bytesRead = try stream.read(into: &buffer, offset: 0, count: 100)

// Get all content
let allBytes = stream.toArray()
```

### MemoryBlockStream

Block-based memory storage for larger content:

```swift
// Uses linked blocks instead of contiguous array
let stream = MemoryBlockStream()

// Same interface as MemoryStream
try stream.write(largeData, offset: 0, count: largeData.count)
```

### BoundStream

Read content up to a boundary (for multipart parsing):

```swift
let boundStream = BoundStream(
    source: inputStream,
    boundary: boundaryBytes
)

// Reads stop at boundary
while let data = try boundStream.readSome() {
    process(data)
}
```

### ChainedStream

Chain multiple streams together:

```swift
let chain = ChainedStream()
chain.add(stream1)
chain.add(stream2)
chain.add(stream3)

// Reads from stream1, then stream2, then stream3
```

### MeasuringStream

Track bytes read/written:

```swift
let measuring = MeasuringStream(wrapping: outputStream)
try message.writeTo(measuring)
print("Message size: \(measuring.bytesWritten) bytes")
```

## Stream Filters

Filters transform data as it flows through streams.

### FilteredStream

Chain filters on a stream:

```swift
// Create output with Base64 encoding
let output = MemoryStream()
let encoder = EncoderFilter(encoding: .base64)
let filtered = FilteredStream(stream: output, filters: [encoder])

// Data written is automatically Base64 encoded
try filtered.write(binaryData, offset: 0, count: binaryData.count)
```

### Encoding Filters

Transform content encoding:

```swift
// Base64 encoding
let base64Encoder = EncoderFilter(encoding: .base64)
let base64Decoder = DecoderFilter(encoding: .base64)

// Quoted-printable
let qpEncoder = EncoderFilter(encoding: .quotedPrintable)
let qpDecoder = DecoderFilter(encoding: .quotedPrintable)
```

### Character Set Filters

Convert between character encodings:

```swift
let charsetFilter = CharsetFilter(
    sourceEncoding: .isoLatin1,
    targetEncoding: .utf8
)
```

### Line Ending Filters

Normalize line endings:

```swift
// Convert to Unix (LF)
let toUnix = Dos2UnixFilter()

// Convert to DOS (CRLF)
let toDos = Unix2DosFilter()
```

### Custom Filters

Create custom filters by implementing the filter protocol:

```swift
class MyFilter: IMimeFilter {
    func filter(input: [UInt8], startIndex: Int, length: Int,
                output: inout [UInt8], outputIndex: inout Int,
                flush: Bool) -> [UInt8] {
        // Transform input to output
        // Return any remaining bytes
    }

    func reset() {
        // Reset filter state
    }
}
```

## Working with MimeContent

``MimeContent`` wraps content with its encoding:

```swift
// Create content from data
let content = MimeContent(data: imageBytes)

// Create from stream
let content = MimeContent(stream: inputStream)

// Read decoded content
let decoded = try content.read()

// Decode to a stream
try content.decode(to: outputStream)

// Write encoded content
try content.encode(to: outputStream, encoding: .base64)
```

## Streaming Large Messages

### Parsing Large Messages

```swift
// Content is loaded lazily
let message = try MimeMessage.load(largeFileStream)

// Access parts without loading all content
for part in message.bodyParts {
    // Each part's content is loaded on demand
    if let mimePart = part as? MimePart {
        let size = mimePart.content?.length ?? 0
        print("Part size: \(size)")
    }
}
```

### Writing Large Attachments

```swift
// Stream attachment from file
let fileStream = try FileInputStream(path: "/large-file.zip")
let content = MimeContent(stream: fileStream)

let attachment = MimePart()
attachment.content = content
attachment.contentTransferEncoding = .base64

// Content is encoded as it's written
try message.writeTo(outputStream)
```

### Processing Attachments

```swift
// Save attachment without loading into memory
guard let content = attachment.content else { return }

let outputPath = "/downloads/\(attachment.fileName ?? "file")"
let outputStream = try FileOutputStream(path: outputPath)

// Streams decoded content directly to file
try content.decode(to: outputStream)
```

## Filter Chains

Combine multiple filters:

```swift
// Chain: input -> charset convert -> encode base64 -> output
let filters = [
    CharsetFilter(sourceEncoding: .utf16, targetEncoding: .utf8),
    EncoderFilter(encoding: .base64)
]

let filtered = FilteredStream(stream: output, filters: filters)
try filtered.write(utf16Data, offset: 0, count: utf16Data.count)
```

## Seeking and Position

```swift
let stream = MemoryStream(data: messageBytes)

// Get current position
let pos = stream.position

// Seek to beginning
try stream.seek(offset: 0, origin: .begin)

// Seek relative to current position
try stream.seek(offset: 100, origin: .current)

// Seek from end
try stream.seek(offset: -10, origin: .end)
```

## Error Handling

```swift
do {
    let bytesRead = try stream.read(into: &buffer, offset: 0, count: buffer.count)
} catch let error as StreamError {
    switch error {
    case .endOfStream:
        print("Reached end of stream")
    case .readError(let message):
        print("Read error: \(message)")
    case .writeError(let message):
        print("Write error: \(message)")
    }
}
```

## Best Practices

### Use Streams for Large Content

```swift
// Good: Stream processing
let content = MimeContent(stream: fileStream)
try content.decode(to: outputStream)

// Avoid: Loading into memory
let allBytes = try fileStream.readAll()  // May exhaust memory
```

### Choose Appropriate Stream Types

```swift
// Small content: MemoryStream
let small = MemoryStream(data: smallBytes)

// Large content: MemoryBlockStream or file-backed
let large = MemoryBlockStream()

// Known size: Pre-allocated MemoryStream
let preallocated = MemoryStream(capacity: knownSize)
```

### Reuse Buffers

```swift
// Reuse buffer across reads
var buffer = [UInt8](repeating: 0, count: 8192)

while true {
    let read = try stream.read(into: &buffer, offset: 0, count: buffer.count)
    if read == 0 { break }
    process(buffer, count: read)
}
```

## Topics

### Related Types

- ``MimeStream``
- ``MemoryStream``
- ``FilteredStream``
- ``MimeContent``

### Related Articles

- <doc:ParsingMessages>
- <doc:Attachments>
