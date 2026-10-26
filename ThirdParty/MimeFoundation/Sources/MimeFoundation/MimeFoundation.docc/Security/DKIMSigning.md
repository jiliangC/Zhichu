# DKIM Signing

Authenticate email messages with DomainKeys Identified Mail.

## Overview

DKIM (DomainKeys Identified Mail) allows sending domains to sign email messages, enabling receiving servers to verify the message originated from the claimed domain and hasn't been modified. Unlike S/MIME, DKIM is designed for server-to-server authentication rather than end-user security.

## How DKIM Works

1. **Signing**: The sending server adds a `DKIM-Signature` header
2. **Publishing**: The domain publishes the public key in DNS
3. **Verification**: Receiving servers fetch the key and verify the signature

## Creating a DKIM Signer

Use ``DkimSigner`` with your domain's private key:

```swift
let privateKey: String = """
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA...
    -----END RSA PRIVATE KEY-----
    """

let signer = DkimSigner(
    privateKey: privateKey,
    domain: "example.com",
    selector: "mail2024"
)
```

### Parameters

- **privateKey**: RSA or Ed25519 private key in PEM format
- **domain**: The signing domain (d= tag)
- **selector**: Key selector for DNS lookup (s= tag)

The DNS TXT record is published at: `{selector}._domainkey.{domain}`

## Signing a Message

```swift
// Create and configure the signer
let signer = DkimSigner(
    privateKey: keyPEM,
    domain: "example.com",
    selector: "default"
)

// Specify which headers to sign
let headersToSign: [HeaderId] = [
    .from,
    .to,
    .subject,
    .date,
    .messageId
]

// Sign the message
try signer.sign(message, headers: headersToSign)

// The message now has a DKIM-Signature header
print(message.headers[.dkimSignature]?.value ?? "")
```

## Configuration Options

### Signature Algorithm

```swift
// RSA with SHA-256 (most common)
signer.signatureAlgorithm = .rsa

// Ed25519 (modern, shorter signatures)
signer.signatureAlgorithm = .ed25519
```

### Canonicalization

Control how headers and body are normalized before signing:

```swift
// Relaxed canonicalization (tolerates minor modifications)
signer.headerCanonicalization = .relaxed
signer.bodyCanonicalization = .relaxed

// Simple canonicalization (strict, no modifications allowed)
signer.headerCanonicalization = .simple
signer.bodyCanonicalization = .simple
```

Common combinations:
- `relaxed/relaxed`: Most tolerant, recommended
- `relaxed/simple`: Tolerant headers, strict body
- `simple/simple`: Strictest, may fail with mailing list modifications

### Body Length Limit

Optionally limit how much of the body is signed:

```swift
// Sign only first 1000 bytes of body
signer.bodyLengthLimit = 1000

// Sign entire body (default)
signer.bodyLengthLimit = nil
```

### Agent/User Identifier

Optionally specify the signing identity:

```swift
signer.agentOrUserIdentifier = "user@example.com"
// Adds i=user@example.com to signature
```

## Headers to Sign

Always sign headers that affect message interpretation:

```swift
// Recommended minimum
let essentialHeaders: [HeaderId] = [
    .from,          // Required by DKIM spec
    .to,
    .subject,
    .date,
    .messageId
]

// Extended set for better protection
let extendedHeaders: [HeaderId] = [
    .from,
    .to,
    .cc,
    .subject,
    .date,
    .messageId,
    .inReplyTo,
    .references,
    .mimeVersion,
    .contentType
]
```

> Important: The `From` header is mandatory per the DKIM specification.

## Verifying DKIM Signatures

Use ``DkimVerifier`` to verify incoming messages:

```swift
let verifier = DkimVerifier()

// You must provide a way to look up public keys
verifier.publicKeyLocator = MyDnsKeyLocator()

// Verify the message
let results = try verifier.verify(message)

for result in results {
    print("Domain: \(result.domain)")
    print("Selector: \(result.selector)")
    print("Valid: \(result.isValid)")
}
```

### Implementing Key Lookup

Implement ``DkimPublicKeyLocator`` to fetch keys from DNS:

```swift
class MyDnsKeyLocator: DkimPublicKeyLocator {
    func locatePublicKey(domain: String, selector: String) async throws -> String {
        // Query DNS for: {selector}._domainkey.{domain}
        // Parse the TXT record
        // Return the public key (p= value)

        let dnsName = "\(selector)._domainkey.\(domain)"
        let txtRecord = try await queryDnsTxt(dnsName)
        return extractPublicKey(from: txtRecord)
    }
}
```

## Complete Signing Example

```swift
import MimeFoundation

// Create the message
let message = MimeMessage()
message.from.add(MailboxAddress(address: "noreply@example.com"))
message.to.add(MailboxAddress(address: "recipient@external.com"))
message.subject = "Newsletter"
message.date = DateTimeOffset.now
message.messageId = MimeUtils.generateMessageId(domain: "example.com")
message.body = TextPart("plain", "Newsletter content...")

// Configure DKIM signer
let signer = DkimSigner(
    privateKey: privateKeyPEM,
    domain: "example.com",
    selector: "mail2024"
)
signer.signatureAlgorithm = .rsa
signer.headerCanonicalization = .relaxed
signer.bodyCanonicalization = .relaxed

// Sign
try signer.sign(message, headers: [
    .from, .to, .subject, .date, .messageId
])

// The message now includes:
// DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
//     d=example.com; s=mail2024;
//     h=from:to:subject:date:message-id;
//     bh=base64-body-hash;
//     b=base64-signature
```

## DNS Record Setup

Publish your public key in DNS:

```
mail2024._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=MIIBIj..."
```

Key record tags:
- `v=DKIM1`: Version
- `k=rsa` or `k=ed25519`: Key type
- `p=...`: Base64-encoded public key

## Async Operations

```swift
// Async signing
try await signer.signAsync(message, headers: headers)

// Async verification
let results = try await verifier.verifyAsync(message)
```

## Error Handling

```swift
do {
    try signer.sign(message, headers: headers)
} catch let error as DkimSignerError {
    switch error {
    case .invalidPrivateKey:
        print("Private key is invalid or unsupported")
    case .missingRequiredHeader:
        print("From header is required")
    case .signingFailed(let message):
        print("Signing failed: \(message)")
    }
}
```

## Best Practices

### Key Management

- Use 2048-bit RSA keys minimum
- Rotate keys periodically (yearly)
- Use dated selectors (`mail2024`) for easy rotation
- Keep private keys secure

### Header Selection

- Always include `From` (required)
- Include headers attackers might modify
- Don't sign headers that might be legitimately modified (like `Received`)

### Canonicalization

- Use `relaxed/relaxed` for best deliverability
- Use `simple/simple` only when strictness is required

### Multiple Signatures

Large organizations may add multiple signatures:

```swift
// Sign with primary domain
let primarySigner = DkimSigner(key1, domain: "example.com", selector: "s1")
try primarySigner.sign(message, headers: headers)

// Sign with subdomain
let subSigner = DkimSigner(key2, domain: "mail.example.com", selector: "s2")
try subSigner.sign(message, headers: headers)
```

## Topics

### Related Types

- ``DkimSigner``
- ``DkimVerifier``
- ``DkimPublicKeyLocator``
- ``DkimSignatureAlgorithm``
- ``DkimCanonicalizationAlgorithm``

### Related Articles

- <doc:SMIMEOverview>
- <doc:SigningMessages>
