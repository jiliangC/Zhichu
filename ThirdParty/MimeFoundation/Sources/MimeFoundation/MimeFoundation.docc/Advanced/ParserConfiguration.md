# Parser Configuration

Customize parsing behavior for different use cases.

## Overview

MimeFoundation's parser is highly configurable, allowing you to balance between strict RFC compliance and lenient handling of real-world malformed messages. The ``ParserOptions`` type controls all parsing behavior.

## Default Configuration

The default configuration works well for most use cases:

```swift
// Use defaults
let message = try MimeMessage.load(stream)

// Or explicitly create default options
let options = ParserOptions()
let message = try MimeMessage.load(stream, options: options)
```

## Compliance Modes

The ``RfcComplianceMode`` enum controls parsing strictness:

### Strict Mode

Enforces RFC compliance; rejects malformed content:

```swift
var options = ParserOptions()
options.addressParserComplianceMode = .strict
options.parameterComplianceMode = .strict
options.rfc2047ComplianceMode = .strict
```

Use strict mode when:
- Processing messages from trusted, well-behaved sources
- Validating message format compliance
- Testing message generation code

### Loose Mode

Accepts malformed content when possible:

```swift
var options = ParserOptions()
options.addressParserComplianceMode = .loose
options.parameterComplianceMode = .loose
options.rfc2047ComplianceMode = .loose
```

Use loose mode when:
- Processing messages from unknown sources
- Handling legacy or broken email clients
- Maximum compatibility is needed

## Address Parsing Options

Configure how email addresses are parsed:

```swift
var options = ParserOptions()

// Compliance mode
options.addressParserComplianceMode = .loose

// Allow addresses without @ and domain (local addresses)
options.allowAddressesWithoutDomain = true

// Allow unquoted commas in address display names
options.allowUnquotedCommasInAddresses = true

// Maximum nesting for group addresses
options.maxAddressGroupDepth = 3
```

### Examples of Lenient Address Parsing

```swift
// Strict mode would reject these; loose mode accepts them:

// Missing quotes around name with special characters
// "John, Jr. <john@example.com>" → works with allowUnquotedCommasInAddresses

// Local address without domain
// "localuser" → works with allowAddressesWithoutDomain

// Malformed but recoverable
// "john@example.com (John Doe)" → loose mode extracts address
```

## Parameter Parsing

Control Content-Type and Content-Disposition parameter parsing:

```swift
var options = ParserOptions()
options.parameterComplianceMode = .loose
```

Loose mode handles:
- Missing quotes around parameter values
- Invalid characters in parameter names
- Malformed RFC 2231 encoded parameters

## RFC 2047 (Encoded Words)

Control header value decoding:

```swift
var options = ParserOptions()
options.rfc2047ComplianceMode = .loose
```

Loose mode handles:
- Invalid charset names
- Malformed encoded word syntax
- Missing whitespace between encoded words

## Security Options

### Maximum MIME Depth

Prevent denial-of-service from deeply nested structures:

```swift
var options = ParserOptions()
options.maxMimeDepth = 100  // Default is 1024

// Protects against "billion laughs" style attacks
```

### Content-Length Handling

Control whether to trust Content-Length headers:

```swift
var options = ParserOptions()

// Trust Content-Length (faster but can be exploited)
options.respectContentLength = true

// Ignore Content-Length (safer, parse to boundary)
options.respectContentLength = false
```

## Character Encoding

### Default Charset

Specify the charset for content without explicit encoding:

```swift
var options = ParserOptions()

// Default to UTF-8 for unknown content
options.charsetEncoding = .utf8

// Or use ISO-8859-1 (common for legacy messages)
options.charsetEncoding = .isoLatin1
```

## Custom MIME Type Handlers

Register custom handlers for specific content types:

```swift
var options = ParserOptions()

// Register a custom handler for a proprietary format
options.registerMimeType(
    mediaType: "application",
    mediaSubtype: "x-custom",
    handler: { headers, stream in
        return try CustomPart(headers: headers, stream: stream)
    }
)
```

## Configuration Patterns

### Maximum Compatibility

For processing messages from any source:

```swift
var options = ParserOptions()
options.addressParserComplianceMode = .loose
options.parameterComplianceMode = .loose
options.rfc2047ComplianceMode = .loose
options.allowAddressesWithoutDomain = true
options.allowUnquotedCommasInAddresses = true
options.charsetEncoding = .utf8
```

### Maximum Security

For processing untrusted messages:

```swift
var options = ParserOptions()
options.maxMimeDepth = 50
options.respectContentLength = false
// Consider using strict modes if possible
```

### Validation Mode

For testing message format compliance:

```swift
var options = ParserOptions()
options.addressParserComplianceMode = .strict
options.parameterComplianceMode = .strict
options.rfc2047ComplianceMode = .strict
```

## Complete Example

```swift
import MimeFoundation

func parseUntrustedMessage(data: [UInt8]) throws -> MimeMessage {
    var options = ParserOptions()

    // Be lenient with format issues
    options.addressParserComplianceMode = .loose
    options.parameterComplianceMode = .loose
    options.rfc2047ComplianceMode = .loose
    options.allowUnquotedCommasInAddresses = true

    // Security protections
    options.maxMimeDepth = 100
    options.respectContentLength = false

    // Character encoding
    options.charsetEncoding = .utf8

    let stream = MemoryStream(data: data)
    return try MimeMessage.load(stream, options: options)
}
```

## Diagnosing Parse Failures

When parsing fails, try progressively looser settings:

```swift
func parseWithFallback(data: [UInt8]) throws -> MimeMessage {
    let stream = MemoryStream(data: data)

    // Try strict first
    do {
        return try MimeMessage.load(stream)
    } catch {
        print("Strict parse failed: \(error)")
    }

    // Reset stream and try loose
    try stream.seek(offset: 0, origin: .begin)

    var options = ParserOptions()
    options.addressParserComplianceMode = .loose
    options.parameterComplianceMode = .loose
    options.rfc2047ComplianceMode = .loose

    return try MimeMessage.load(stream, options: options)
}
```

## Topics

### Related Types

- ``ParserOptions``
- ``RfcComplianceMode``
- ``MimeParser``

### Related Articles

- <doc:ParsingMessages>
