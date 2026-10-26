# Verifying Signatures

Validate digital signatures on received messages.

## Overview

When you receive a signed message, verifying the signature confirms the sender's identity and ensures the message hasn't been tampered with. MimeFoundation provides tools to verify both clear-signed and opaque-signed messages.

## Detecting Signed Messages

Check if a message is signed:

```swift
// Clear-signed (multipart/signed)
if let signed = message.body as? MultipartSigned {
    print("Message is clear-signed")
}

// Opaque-signed (application/pkcs7-mime with signed-data)
if let pkcs7 = message.body as? ApplicationPkcs7Mime,
   pkcs7.secureType == .signedData {
    print("Message is opaque-signed")
}
```

## Verifying Clear-Signed Messages

Clear-signed messages use `multipart/signed`:

```swift
guard let signed = message.body as? MultipartSigned else {
    print("Not a signed message")
    return
}

let context = DefaultSecureMimeContext.shared

// Verify the signature
let signatures = try context.verify(signed)

// Check each signature
for signature in signatures {
    print("Signed by: \(signature.signer)")
    print("Algorithm: \(signature.signatureAlgorithm)")
    print("Digest: \(signature.digestAlgorithm)")

    if let created = signature.creationTime {
        print("Signed at: \(created)")
    }

    if signature.isExpired {
        print("Warning: Certificate has expired")
    }
}

// Access the original signed content
if let content = signed.signedContent {
    // Process the verified content
    if let textPart = content as? TextPart {
        print("Verified content: \(textPart.text)")
    }
}
```

## Verifying Opaque-Signed Messages

Opaque-signed messages wrap content in `application/pkcs7-mime`:

```swift
guard let pkcs7 = message.body as? ApplicationPkcs7Mime,
      pkcs7.secureType == .signedData else {
    print("Not an opaque-signed message")
    return
}

let context = DefaultSecureMimeContext.shared

// Verify and extract content
let (content, signatures) = try context.verifyAndExtract(pkcs7)

// Check signatures
for signature in signatures {
    print("Signed by: \(signature.signer)")
}

// Process the extracted content
if let text = content as? TextPart {
    print("Content: \(text.text)")
}
```

## Async Verification

For non-blocking operation:

```swift
let signatures = try await context.verifyAsync(signed)
```

## The DigitalSignature Type

``DigitalSignature`` contains signature verification results:

```swift
struct DigitalSignature {
    /// The certificate that created this signature
    let signer: Certificate

    /// The signature algorithm used
    let signatureAlgorithm: SignatureAlgorithm

    /// The hash algorithm used
    let digestAlgorithm: DigestAlgorithm

    /// When the signature was created (if available)
    let creationTime: Date?

    /// Whether the certificate has expired
    var isExpired: Bool
}
```

## Validating Signer Identity

After verification, validate the signer's identity:

```swift
let signatures = try context.verify(signed)

for signature in signatures {
    // Get signer certificate
    let cert = signature.signer

    // Check certificate subject (example - actual API may vary)
    // print("Subject: \(cert.subject)")

    // Check if from expected sender
    let expectedEmail = "alice@example.com"
    // Implement your own email extraction from certificate

    // Check validity period
    if signature.isExpired {
        print("Warning: Certificate expired")
    }
}
```

## Handling Verification Failures

```swift
do {
    let signatures = try context.verify(signed)

    if signatures.isEmpty {
        print("No valid signatures found")
    }
} catch let error as SecureMimeError {
    switch error {
    case .signatureVerificationFailed:
        print("Signature is invalid - message may have been tampered with")
    case .invalidSignature:
        print("Signature format is invalid")
    case .certificateChainIncomplete:
        print("Cannot verify - missing intermediate certificates")
    default:
        print("Verification error: \(error)")
    }
}
```

## Complete Verification Example

```swift
import MimeFoundation

func processSecureMessage(_ message: MimeMessage) throws {
    // Check for encryption first
    if let encrypted = message.body as? ApplicationPkcs7Mime,
       encrypted.secureType == .envelopedData {
        // Decrypt first
        let decrypted = try context.decrypt(encrypted)
        // Then check if decrypted content is signed
        try verifyIfSigned(decrypted)
        return
    }

    // Check for signature
    try verifyIfSigned(message.body)
}

func verifyIfSigned(_ entity: MimeEntity?) throws {
    guard let entity = entity else { return }

    let context = DefaultSecureMimeContext.shared

    // Clear-signed
    if let signed = entity as? MultipartSigned {
        let signatures = try context.verify(signed)
        reportSignatures(signatures)

        // Process verified content
        if let content = signed.signedContent {
            print("Verified content type: \(content.contentType)")
        }
        return
    }

    // Opaque-signed
    if let pkcs7 = entity as? ApplicationPkcs7Mime,
       pkcs7.secureType == .signedData {
        let (content, signatures) = try context.verifyAndExtract(pkcs7)
        reportSignatures(signatures)
        print("Extracted content type: \(content.contentType)")
        return
    }

    print("Message is not signed")
}

func reportSignatures(_ signatures: [DigitalSignature]) {
    print("Found \(signatures.count) signature(s)")

    for (index, sig) in signatures.enumerated() {
        print("Signature \(index + 1):")
        print("  Digest algorithm: \(sig.digestAlgorithm)")

        if let created = sig.creationTime {
            print("  Created: \(created)")
        }

        if sig.isExpired {
            print("  ⚠️ Certificate expired")
        } else {
            print("  ✓ Certificate valid")
        }
    }
}
```

## Trust Decisions

Signature verification proves cryptographic validity. Trust decisions require additional checks:

```swift
func shouldTrustSignature(_ signature: DigitalSignature) -> Bool {
    // 1. Check expiration
    guard !signature.isExpired else {
        print("Rejected: Certificate expired")
        return false
    }

    // 2. Check algorithm strength
    guard signature.digestAlgorithm != .sha1 else {
        print("Warning: Weak digest algorithm (SHA-1)")
        return false
    }

    // 3. Implement additional trust checks:
    // - Is the certificate from a trusted CA?
    // - Is the email address in the certificate expected?
    // - Is the certificate revoked?

    return true
}
```

## Best Practices

### Always Verify Signed Messages

```swift
// Don't just check if signed—verify the signature
if let signed = message.body as? MultipartSigned {
    do {
        let signatures = try context.verify(signed)
        // Only trust content after successful verification
    } catch {
        print("Signature verification failed!")
        // Treat as untrusted
    }
}
```

### Check Certificate Validity

```swift
for signature in signatures {
    if signature.isExpired {
        // Warn user but may still accept
        print("Signed with expired certificate")
    }
}
```

### Validate Sender Identity

```swift
// Ensure signer matches expected sender
let fromAddress = message.from.first?.address
// Compare with certificate subject/email extension
```

### Log Verification Results

```swift
func logVerification(_ message: MimeMessage, signatures: [DigitalSignature]) {
    let messageId = message.messageId ?? "unknown"
    print("[\(messageId)] Verified with \(signatures.count) signature(s)")

    for sig in signatures {
        print("  - \(sig.digestAlgorithm), expired=\(sig.isExpired)")
    }
}
```

## Topics

### Related Types

- ``DigitalSignature``
- ``MultipartSigned``
- ``ApplicationPkcs7Mime``
- ``SecureMimeContext``

### Related Articles

- <doc:SMIMEOverview>
- <doc:SigningMessages>
- <doc:EncryptingMessages>
