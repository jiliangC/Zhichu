# Encrypting Messages

Protect message confidentiality with S/MIME encryption.

## Overview

S/MIME encryption ensures only intended recipients can read your messages. MimeFoundation encrypts using public-key cryptography—you encrypt with the recipient's public key (from their certificate), and they decrypt with their private key.

> Important: S/MIME encryption is currently **only available on macOS**. It requires the Security
> framework's CMSEncoder and CMSDecoder APIs. iOS, tvOS, watchOS, and Linux support signing and
> verification but not encryption.

## Prerequisites

To encrypt messages, you need:

- **macOS 11.0 or later** (encryption is not available on other platforms)
- The recipient's X.509 certificate containing their public key
- The certificate must be valid for email encryption

## Creating Recipients

Use ``CmsRecipient`` to represent each recipient:

```swift
// From PEM-encoded certificate
let recipient = try CmsRecipient(pemEncoded: """
    -----BEGIN CERTIFICATE-----
    MIICxjCCAa6g...
    -----END CERTIFICATE-----
    """)
```

### Loading from Files

```swift
let certPEM = try String(contentsOfFile: "/path/to/recipient-cert.pem")
let recipient = try CmsRecipient(pemEncoded: certPEM)
```

### From DER-Encoded Data

```swift
let certData: [UInt8] = // ... DER-encoded certificate bytes
let recipient = try CmsRecipient(derEncoded: certData)
```

### Multiple Recipients

Encrypt for multiple recipients so each can decrypt:

```swift
let recipients = [
    try CmsRecipient(pemEncoded: aliceCert),
    try CmsRecipient(pemEncoded: bobCert),
    try CmsRecipient(pemEncoded: carolCert)
]
```

## Choosing the Right Context

MimeFoundation provides two S/MIME contexts:

- **`DefaultSecureMimeContext`**: Cross-platform, supports signing only
- **`AppleSecureMimeContext`**: macOS only, supports signing AND encryption

For encryption, you must use `AppleSecureMimeContext`:

```swift
#if os(macOS)
let context = AppleSecureMimeContext.shared
// Encryption available
#else
let context = DefaultSecureMimeContext.shared
// Signing only - encryption not available
#endif
```

## Encrypting a Message

Use the Apple S/MIME context to encrypt (macOS only):

```swift
#if os(macOS)
let context = AppleSecureMimeContext.shared

// Create recipients
let recipient = try CmsRecipient(pemEncoded: recipientCertPEM)

// Encrypt the message body
let encrypted = try context.encrypt(
    recipients: CmsRecipientCollection([recipient]),
    entity: message.body!
)

// Replace the body with encrypted content
message.body = encrypted
#endif
```

The result is an `ApplicationPkcs7Mime` part:

```
Content-Type: application/pkcs7-mime;
    smime-type=enveloped-data;
    name="smime.p7m"
Content-Transfer-Encoding: base64

[Base64 encoded EnvelopedData]
```

## Complete Encryption Example

```swift
import MimeFoundation

// Create the message
let message = MimeMessage()
message.from.add(MailboxAddress(name: "Alice", address: "alice@example.com"))
message.to.add(MailboxAddress(name: "Bob", address: "bob@example.com"))
message.subject = "Confidential: Account Details"

// Create the body
let body = try Multipart("mixed")
try body.add(TextPart("plain", """
    Hi Bob,

    Here are your account credentials:
    Username: bob_secure
    Password: [see attached file]

    Please change your password after first login.
    """))
try body.add(MimePart(fileName: "/secure/credentials.txt"))
message.body = body

// Load Bob's certificate
let bobCert = try String(contentsOfFile: "bob-cert.pem")
let recipient = try CmsRecipient(pemEncoded: bobCert)

// Encrypt
let context = DefaultSecureMimeContext.shared
let encrypted = try context.encrypt([recipient], entity: message.body!)
message.body = encrypted

// Serialize
let output = MemoryStream()
try message.writeTo(output)
```

## Async Encryption

For non-blocking operation:

```swift
let encrypted = try await context.encryptAsync(recipients, entity: message.body!)
message.body = encrypted
```

## Sign Then Encrypt

For maximum security, sign the message before encrypting:

```swift
// 1. Create the message body
let body = TextPart("plain", "Confidential signed content")

// 2. Sign it first
let signer = try CmsSigner(
    certificatePEM: aliceCert,
    privateKeyPEM: aliceKey
)
let signed = try MultipartSigned.create(body, signer: signer, context: context)

// 3. Then encrypt the signed content
let recipient = try CmsRecipient(pemEncoded: bobCert)
let encrypted = try context.encrypt([recipient], entity: signed)

message.body = encrypted
```

Benefits:
- Confidentiality: Only Bob can decrypt
- Authentication: Bob knows Alice signed it
- Integrity: Any tampering is detected
- Privacy: Observers don't know who signed

## Decrypting Messages

To decrypt received messages:

```swift
// Check if message is encrypted
guard let encryptedPart = message.body as? ApplicationPkcs7Mime,
      encryptedPart.secureType == .envelopedData else {
    print("Message is not encrypted")
    return
}

// Decrypt (requires your private key to be available)
let decrypted = try context.decrypt(encryptedPart)

// decrypted is the original MimeEntity
if let text = decrypted as? TextPart {
    print("Decrypted content: \(text.text)")
}
```

## Algorithm Selection

S/MIME uses symmetric encryption for the content and asymmetric encryption for the key. The library selects appropriate algorithms automatically, but you can verify the encryption method in received messages:

```swift
if let pkcs7 = message.body as? ApplicationPkcs7Mime {
    print("S/MIME type: \(pkcs7.secureType)")
}
```

## Encrypting for Self

To read encrypted messages you send, include yourself as a recipient:

```swift
let recipients = [
    try CmsRecipient(pemEncoded: recipientCert),
    try CmsRecipient(pemEncoded: myCert)  // Include yourself
]

let encrypted = try context.encrypt(recipients, entity: body)
```

## Error Handling

```swift
do {
    let encrypted = try context.encrypt(recipients, entity: body)
} catch let error as SecureMimeError {
    switch error {
    case .encryptionFailed(let message):
        print("Encryption failed: \(message)")
    case .invalidCertificate:
        print("Invalid recipient certificate")
    case .certificateNotForEncryption:
        print("Certificate cannot be used for encryption")
    default:
        print("S/MIME error: \(error)")
    }
}
```

## Certificate Validation

Before encrypting, consider validating recipient certificates:

```swift
// The CmsRecipient initializer performs basic validation
do {
    let recipient = try CmsRecipient(pemEncoded: certPEM)
    // Certificate is structurally valid
} catch {
    print("Invalid certificate: \(error)")
}

// For additional validation (expiration, trust chain),
// implement custom checks or use platform certificate APIs
```

## Best Practices

### Validate Certificates

Ensure recipient certificates are:
- Not expired
- Issued by a trusted CA
- Valid for email encryption

### Use Appropriate Key Sizes

- RSA: 2048 bits minimum, 4096 recommended
- ECDSA: P-256 or higher

### Include Yourself as Recipient

Always encrypt to yourself to maintain access:

```swift
let allRecipients = recipients + [try CmsRecipient(pemEncoded: myCert)]
```

### Handle Missing Certificates

```swift
func encryptIfPossible(_ message: MimeMessage, certificates: [String?]) throws {
    let validRecipients = certificates.compactMap { cert -> CmsRecipient? in
        guard let certPEM = cert else { return nil }
        return try? CmsRecipient(pemEncoded: certPEM)
    }

    guard !validRecipients.isEmpty else {
        print("Warning: No valid certificates, sending unencrypted")
        return
    }

    let encrypted = try context.encrypt(validRecipients, entity: message.body!)
    message.body = encrypted
}
```

## Topics

### Related Types

- ``CmsRecipient``
- ``ApplicationPkcs7Mime``
- ``SecureMimeContext``
- ``SecureMimeType``

### Related Articles

- <doc:SMIMEOverview>
- <doc:SigningMessages>
- <doc:VerifyingSignatures>
