# Signing Messages

Add digital signatures to prove authenticity and detect tampering.

## Overview

Digital signatures cryptographically bind a message to the sender's identity. When you sign a message, recipients can verify that you sent it and that it hasn't been modified. MimeFoundation supports S/MIME signing with X.509 certificates.

## Prerequisites

To sign messages, you need:

1. An X.509 certificate containing your public key
2. The corresponding private key
3. Optionally, intermediate certificates for the chain

## Creating a Signer

Use ``CmsSigner`` to represent your signing credentials:

```swift
// From PEM-encoded certificate and key
let signer = try CmsSigner(
    certificatePEM: """
        -----BEGIN CERTIFICATE-----
        MIICxjCCAa6g...
        -----END CERTIFICATE-----
        """,
    privateKeyPEM: """
        -----BEGIN PRIVATE KEY-----
        MIIEvgIBADAN...
        -----END PRIVATE KEY-----
        """
)
```

### Loading from Files

```swift
// Using file paths directly
let signer = try CmsSigner(
    certificatePath: "/path/to/cert.pem",
    privateKeyPath: "/path/to/key.pem"
)

// Or loading content manually
let certPEM = try String(contentsOfFile: "/path/to/cert.pem")
let keyPEM = try String(contentsOfFile: "/path/to/key.pem")

let signer = try CmsSigner(
    certificatePEM: certPEM,
    privateKeyPEM: keyPEM
)
```

### Loading from PKCS#12 Files

PKCS#12 (.p12 or .pfx) files bundle a certificate and private key together with password protection.

> Important: Due to key format incompatibilities between Apple's Security framework and swift-crypto,
> direct PKCS#12 import is not currently supported for signing. You must first convert your PKCS#12
> file to PEM format.

**Converting PKCS#12 to PEM with OpenSSL:**

```bash
# Extract the private key (enter PKCS#12 password when prompted)
openssl pkcs12 -in certificate.p12 -nocerts -nodes -out private-key.pem

# Extract the certificate
openssl pkcs12 -in certificate.p12 -clcerts -nokeys -out certificate.pem

# Optional: Extract intermediate certificates (if any)
openssl pkcs12 -in certificate.p12 -cacerts -nokeys -out intermediates.pem
```

Then load the PEM files:

```swift
let signer = try CmsSigner(
    certificatePath: "certificate.pem",
    privateKeyPath: "private-key.pem"
)
```

> Note: This limitation affects the `CmsSigner` class specifically. If you need to work with
> PKCS#12 files directly for other purposes (like encryption on macOS), the Security framework
> can import them via `SecPKCS12Import`.

### With Certificate Chain

Include intermediate certificates for full chain validation:

```swift
let signer = try CmsSigner(
    certificatePEM: endEntityCert,
    privateKeyPEM: privateKey,
    certificateChain: [intermediateCert1, intermediateCert2]
)
```

### Specifying Digest Algorithm

Choose the hash algorithm for signing:

```swift
let signer = try CmsSigner(
    certificatePEM: cert,
    privateKeyPEM: key,
    digestAlgorithm: .sha256  // Default
)

// Available algorithms:
// .sha256 (recommended)
// .sha384
// .sha512
// .sha1 (legacy, not recommended)
```

## Signing Methods

### Clear Signing (multipart/signed)

Creates a message where the content is readable without decryption:

```swift
let context = DefaultSecureMimeContext.shared

// Create signed multipart
let signed = try MultipartSigned.create(
    message.body!,
    signer: signer,
    context: context
)

message.body = signed
```

The resulting structure:

```
Content-Type: multipart/signed;
    protocol="application/pkcs7-signature";
    micalg=sha-256;
    boundary="----=_Part_1"

------=_Part_1
Content-Type: text/plain

Original message content here...

------=_Part_1
Content-Type: application/pkcs7-signature
Content-Transfer-Encoding: base64

[Base64 encoded signature]
------=_Part_1--
```

### Opaque Signing (application/pkcs7-mime)

Creates an opaque signed message (content not readable without processing):

```swift
let opaqueSigned = try context.sign(signer, content: message.body!)
message.body = opaqueSigned
```

The resulting structure:

```
Content-Type: application/pkcs7-mime;
    smime-type=signed-data;
    name="smime.p7m"
Content-Transfer-Encoding: base64

[Base64 encoded SignedData]
```

## Complete Signing Example

```swift
import MimeFoundation

// Create the message
let message = MimeMessage()
message.from.add(MailboxAddress(name: "Alice", address: "alice@example.com"))
message.to.add(MailboxAddress(name: "Bob", address: "bob@example.com"))
message.subject = "Signed Contract"

// Create body with attachment
let body = try Multipart("mixed")
try body.add(TextPart("plain", "Please find the signed contract attached."))
try body.add(MimePart(fileName: "/contracts/agreement.pdf"))
message.body = body

// Load signing credentials
let signer = try CmsSigner(
    certificatePEM: String(contentsOfFile: "alice-cert.pem"),
    privateKeyPEM: String(contentsOfFile: "alice-key.pem"),
    digestAlgorithm: .sha256
)

// Sign the message
let context = DefaultSecureMimeContext.shared
let signed = try MultipartSigned.create(
    message.body!,
    signer: signer,
    context: context
)

message.body = signed

// Serialize for sending
let output = MemoryStream()
try message.writeTo(output)
```

## Async Signing

For non-blocking operation:

```swift
let signed = try await context.signAsync(signer, content: message.body!)
message.body = signed
```

## Signing Best Practices

### Use Strong Algorithms

```swift
// Good: SHA-256 or higher
let signer = try CmsSigner(cert, key, digestAlgorithm: .sha256)

// Better: SHA-384 for increased security
let signer = try CmsSigner(cert, key, digestAlgorithm: .sha384)

// Avoid: SHA-1 (deprecated)
// let signer = try CmsSigner(cert, key, digestAlgorithm: .sha1)
```

### Include Certificate Chain

For recipients to validate your signature, include intermediates:

```swift
let signer = try CmsSigner(
    certificatePEM: endEntity,
    privateKeyPEM: key,
    certificateChain: [intermediate1, intermediate2]
)
```

### Verify Before Sending

Test that your signature is valid:

```swift
// Sign
let signed = try MultipartSigned.create(body, signer: signer, context: context)

// Immediately verify (optional sanity check)
let signatures = try context.verify(signed)
assert(!signatures.isEmpty, "Signature verification failed")
```

## Combining with Encryption

For maximum security, sign then encrypt:

```swift
// 1. Sign the message
let signed = try MultipartSigned.create(
    message.body!,
    signer: signer,
    context: context
)

// 2. Encrypt the signed content
let encrypted = try context.encrypt(recipients, entity: signed)

message.body = encrypted
```

This approach:
- Hides the signer's identity from observers
- Proves the sender signed before encryption
- Provides both authentication and confidentiality

## Error Handling

```swift
do {
    let signed = try MultipartSigned.create(body, signer: signer, context: context)
} catch let error as SecureMimeError {
    switch error {
    case .signingFailed(let message):
        print("Signing failed: \(message)")
    case .invalidCertificate:
        print("Invalid certificate")
    case .privateKeyMismatch:
        print("Private key doesn't match certificate")
    default:
        print("S/MIME error: \(error)")
    }
}
```

## Topics

### Related Types

- ``CmsSigner``
- ``MultipartSigned``
- ``SecureMimeContext``
- ``DigestAlgorithm``

### Related Articles

- <doc:SMIMEOverview>
- <doc:EncryptingMessages>
- <doc:VerifyingSignatures>
