# Format Configuration

Control how messages are serialized and formatted.

## Overview

When writing MIME messages, ``FormatOptions`` controls the output format including line endings, encoding methods, line length limits, and international character handling. Proper configuration ensures maximum compatibility with receiving mail systems.

## Default Configuration

The default settings work for most SMTP scenarios:

```swift
// Use defaults
try message.writeTo(stream)

// Or explicitly
let options = FormatOptions()
try message.writeTo(stream, options: options)
```

## Line Endings

Control the newline format:

```swift
var options = FormatOptions()

// CRLF for email (required by RFC 5321)
options.newLineFormat = .dos

// LF for local storage or Unix systems
options.newLineFormat = .unix
```

### Ensure Final Newline

Guarantee a newline at the end of the message:

```swift
options.ensureNewLine = true  // Default
```

## Line Length

Control maximum line length for headers and encoded content:

```swift
var options = FormatOptions()

// RFC 5322 recommends 78 characters (default)
options.maxLineLength = 78

// RFC 5322 allows up to 998 characters
options.maxLineLength = 998

// Minimum allowed is 60
options.maxLineLength = 60
```

Long lines are folded (wrapped) according to RFC 5322 rules.

## International Characters

### UTF-8 in Headers

Allow UTF-8 characters in headers (EAI - Email Address Internationalization):

```swift
var options = FormatOptions()

// Enable international headers (requires SMTPUTF8 support)
options.international = true

// Traditional encoding only (RFC 2047)
options.international = false  // Default
```

### Mixed Charsets

Allow different charsets within a single header:

```swift
options.allowMixedHeaderCharsets = true
```

## Parameter Encoding

Control how Content-Type and Content-Disposition parameters are encoded:

```swift
var options = FormatOptions()

// Modern RFC 2231 encoding (recommended)
options.parameterEncodingMethod = .rfc2231

// Legacy quoted encoding
options.parameterEncodingMethod = .rfc2045Quoted

// Legacy unquoted encoding
options.parameterEncodingMethod = .rfc2045Unquoted
```

### RFC 2231 vs RFC 2045

RFC 2231 is preferred for:
- International filenames
- Long parameter values
- Better interoperability with modern clients

```swift
// RFC 2231 output example:
// Content-Disposition: attachment;
//     filename*=utf-8''%E6%97%A5%E6%9C%AC%E8%AA%9E.pdf

// RFC 2045 output example:
// Content-Disposition: attachment;
//     filename="=?UTF-8?B?5pel5pys6Kqe?=.pdf"
```

### Always Quote Parameter Values

Force quoting even for simple ASCII values:

```swift
options.alwaysQuoteParameterValues = true

// With quoting: name="simple"
// Without quoting: name=simple
```

## Complete Configuration Examples

### For Standard SMTP

```swift
var options = FormatOptions()
options.newLineFormat = .dos      // CRLF required
options.maxLineLength = 78         // Recommended
options.parameterEncodingMethod = .rfc2231
options.international = false      // Unless SMTPUTF8 supported

try message.writeTo(stream, options: options)
```

### For Local Storage

```swift
var options = FormatOptions()
options.newLineFormat = .unix     // LF for Unix systems
options.maxLineLength = 998        // Maximum allowed
options.ensureNewLine = true

try message.writeTo(stream, options: options)
```

### For Maximum Compatibility

```swift
var options = FormatOptions()
options.newLineFormat = .dos
options.maxLineLength = 76         // Very safe
options.parameterEncodingMethod = .rfc2231
options.international = false
options.alwaysQuoteParameterValues = true

try message.writeTo(stream, options: options)
```

### For Modern Clients (EAI)

```swift
var options = FormatOptions()
options.international = true       // UTF-8 headers
options.allowMixedHeaderCharsets = true
options.parameterEncodingMethod = .rfc2231

try message.writeTo(stream, options: options)
```

## Preparing Messages

The `prepare()` method optimizes encoding before serialization:

```swift
// Prepare with 7-bit constraint (standard SMTP)
try message.prepare(constraint: .sevenBit)

// Prepare with 8-bit constraint (8BITMIME extension)
try message.prepare(constraint: .eightBit)

// No constraint
try message.prepare(constraint: .none)
```

### Encoding Constraints

``EncodingConstraint`` determines content transfer encoding:

| Constraint | Effect |
|------------|--------|
| `.sevenBit` | All content encoded as 7-bit safe (base64/quoted-printable) |
| `.eightBit` | 8-bit content allowed, but CRLF line endings required |
| `.none` | No restrictions on content encoding |

```swift
// For standard SMTP servers
try message.prepare(constraint: .sevenBit)

// For servers with 8BITMIME
try message.prepare(constraint: .eightBit)

// Prepare then write
try message.prepare(constraint: .sevenBit)
try message.writeTo(stream, options: options)
```

## Combining Options

```swift
let message = MimeMessage()
// ... build message ...

// Prepare with encoding constraint
try message.prepare(constraint: .sevenBit)

// Configure output format
var options = FormatOptions()
options.newLineFormat = .dos
options.maxLineLength = 78

// Write with options
try message.writeTo(stream, options: options)
```

## Effects on Output

### Header Folding

Long headers are folded at whitespace:

```swift
// With maxLineLength = 78:
// Subject: This is a very long subject line that needs to be
//     folded to comply with line length limits
```

### Parameter Continuation

Long parameters use RFC 2231 continuation:

```swift
// With RFC 2231:
// Content-Type: application/octet-stream;
//     name*0="very-long-filename-that-needs-";
//     name*1="continuation.pdf"
```

### Transfer Encoding Selection

Based on constraint and content:

```swift
// 7-bit constraint + binary content → base64
// 7-bit constraint + mostly ASCII text → quoted-printable
// 8-bit constraint + text → 8bit
// No constraint → binary or as-is
```

## Topics

### Related Types

- ``FormatOptions``
- ``EncodingConstraint``
- ``NewLineFormat``
- ``ParameterEncodingMethod``

### Related Articles

- <doc:EncodingAndCharsets>
- <doc:CreatingMessages>
