# S/MIME Overview

Secure your email messages with digital signatures and encryption.

## Overview

S/MIME (Secure/Multipurpose Internet Mail Extensions) provides cryptographic security for email messages through digital signatures and encryption. MimeFoundation includes comprehensive S/MIME support built on Apple's CryptoKit and the Swift Certificates library.

## What S/MIME Provides

S/MIME offers two primary security features:

### Digital Signatures

Signing a message provides:

- **Authentication**: Proves the message came from the claimed sender
- **Integrity**: Detects if the message was modified in transit
- **Non-repudiation**: The sender cannot deny sending the signed message

### Encryption

Encrypting a message provides:

- **Confidentiality**: Only intended recipients can read the message
- **Privacy**: Message content is protected from interception

## Platform Requirements

S/MIME features require:

| Platform | Minimum Version |
|----------|-----------------|
| macOS    | 11.0+           |
| iOS      | 14.0+           |
| tvOS     | 14.0+           |
| watchOS  | 7.0+            |
| Linux    | Swift 5.9+      |

### Feature Availability by Platform

| Feature | macOS | iOS/tvOS/watchOS | Linux |
|---------|-------|------------------|-------|
| Signing | ✅ | ✅ | ✅ |
| Signature Verification | ✅ | ✅ | ✅ |
| Encryption | ✅ | ❌ | ❌ |
| Decryption | ✅ | ❌ | ❌ |

> Note: Encryption and decryption require Apple's Security framework (CMSEncoder/CMSDecoder),
> which is only available on macOS. Cross-platform encryption support is pending the addition
> of EnvelopedData support in swift-certificates.

## Key Concepts

### Certificates

X.509 certificates bind a public key to an identity. You need:

- **Your certificate + private key**: For signing messages you send
- **Recipient certificates**: For encrypting messages to others

MimeFoundation provides a complete certificate management infrastructure including
in-memory stores, persistent SQLite databases, and chain validation. See
<doc:CertificateManagement> for details.

### S/MIME Context

The ``SecureMimeContext`` provides cryptographic operations:

```swift
// Use the default context
let context = DefaultSecureMimeContext.shared

// Or create an Apple-specific context
let appleContext = AppleSecureMimeContext()
```

### PKCS#7/CMS

S/MIME uses Cryptographic Message Syntax (CMS) for:

- **SignedData**: Digital signatures
- **EnvelopedData**: Encrypted content
- **CompressedData**: Compressed content (rare)

## Quick Start: Signing

```swift
import MimeFoundation

// Load your signing certificate and key
let signer = try CmsSigner(
    certificatePEM: signingCertPEM,
    privateKeyPEM: privateKeyPEM
)

// Create your message
let message = MimeMessage()
message.body = TextPart("plain", "This message is signed.")

// Sign the message
let context = DefaultSecureMimeContext.shared
let signed = try MultipartSigned.create(
    message.body!,
    signer: signer,
    context: context
)

message.body = signed
```

## Quick Start: Encryption

```swift
// Load recipient's certificate
let recipient = try CmsRecipient(pemEncoded: recipientCertPEM)

// Encrypt the message body
let context = DefaultSecureMimeContext.shared
let encrypted = try context.encrypt([recipient], entity: message.body!)

message.body = encrypted
```

## S/MIME Message Types

MimeFoundation represents S/MIME content with specific types:

### MultipartSigned

Clear-signed messages where the original content is readable:

```
Content-Type: multipart/signed; protocol="application/pkcs7-signature"

--boundary
[Original message - readable]
--boundary
[Detached signature]
--boundary--
```

### ApplicationPkcs7Mime

Encrypted or opaque-signed content:

```
Content-Type: application/pkcs7-mime; smime-type=enveloped-data
Content-Transfer-Encoding: base64

[Base64-encoded encrypted content]
```

### ApplicationPkcs7Signature

Detached signature (used in multipart/signed):

```
Content-Type: application/pkcs7-signature
Content-Transfer-Encoding: base64

[Base64-encoded signature]
```

## Security Considerations

### Certificate Validation

Always validate certificates before trusting signatures:

```swift
let signatures = try context.verify(signed)
for signature in signatures {
    // Check certificate validity
    if signature.isExpired {
        print("Warning: Certificate expired")
    }

    // Check signer identity
    print("Signed by: \(signature.signer)")
}
```

### Key Management

- Store private keys securely (Keychain recommended)
- Use strong key sizes (RSA 2048+ or ECDSA P-256+)
- Rotate certificates before expiration
- Revoke compromised certificates immediately

### Algorithm Selection

Use modern algorithms:

```swift
let signer = try CmsSigner(
    certificatePEM: cert,
    privateKeyPEM: key,
    digestAlgorithm: .sha256  // Recommended minimum
)
```

Supported digest algorithms:
- SHA-256 (recommended)
- SHA-384
- SHA-512
- SHA-1 (legacy, not recommended)

## Common Use Cases

### Sign All Outgoing Messages

```swift
func prepareSecureMessage(_ message: MimeMessage, signer: CmsSigner) throws {
    guard let body = message.body else { return }

    let signed = try MultipartSigned.create(
        body,
        signer: signer,
        context: DefaultSecureMimeContext.shared
    )

    message.body = signed
}
```

### Encrypt Sensitive Messages

```swift
func encryptForRecipients(_ message: MimeMessage, certificates: [String]) throws {
    let recipients = try certificates.map { try CmsRecipient(pemEncoded: $0) }

    let encrypted = try DefaultSecureMimeContext.shared.encrypt(
        recipients,
        entity: message.body!
    )

    message.body = encrypted
}
```

### Sign and Encrypt

```swift
// First sign
let signed = try MultipartSigned.create(body, signer: signer, context: context)

// Then encrypt the signed content
let encrypted = try context.encrypt(recipients, entity: signed)

message.body = encrypted
```

### Verify Incoming Messages

```swift
func verifyMessage(_ message: MimeMessage) throws -> Bool {
    guard let signed = message.body as? MultipartSigned else {
        return false  // Not signed
    }

    let context = DefaultSecureMimeContext.shared
    let signatures = try context.verify(signed)

    return signatures.allSatisfy { !$0.isExpired }
}
```

## Next Steps

- <doc:SigningMessages> - Detailed guide to signing
- <doc:EncryptingMessages> - Detailed guide to encryption
- <doc:VerifyingSignatures> - Verifying signed messages
- <doc:CertificateManagement> - Managing certificates and trust

## Topics

### Related Types

- ``SecureMimeContext``
- ``AppleSecureMimeContext``
- ``CmsSigner``
- ``CmsRecipient``
- ``MultipartSigned``
- ``ApplicationPkcs7Mime``

### Related Articles

- <doc:SigningMessages>
- <doc:EncryptingMessages>
- <doc:VerifyingSignatures>
- <doc:CertificateManagement>
