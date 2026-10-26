# Certificate Management

Store, retrieve, and validate X.509 certificates for S/MIME operations.

## Overview

MimeFoundation provides a comprehensive certificate management infrastructure for S/MIME
operations. This includes in-memory certificate stores, persistent SQLite databases with
encrypted private key storage, and RFC 5280-compliant chain validation.

## Key Components

### X509CertificateStore

An in-memory, thread-safe certificate store for temporary or session-based operations:

```swift
import MimeFoundation
@_spi(CMS) import X509

// Create an empty store
let store = X509CertificateStore()

// Add certificates
store.add(certificate)
store.add(certificate, privateKey: key)  // With private key

// Find certificates
if let cert = store.find(fingerprint: "a1b2c3...") {
    print("Found: \(cert.subjectString)")
}

// Get certificates with private keys (for signing)
let signingCerts = store.certificatesWithPrivateKeys()
```

### SqliteCertificateDatabase

A persistent SQLite-based database with encrypted private key storage:

```swift
// Create a file-based database
let db = try SqliteCertificateDatabase(
    path: "/path/to/certificates.db",
    password: "encryption-password"
)

// Or an in-memory database for testing
let testDb = try SqliteCertificateDatabase(
    inMemory: true,
    password: "test"
)

// Add certificates
let record = X509CertificateRecord(
    certificate: cert,
    privateKey: key,
    isTrusted: true
)
try db.add(record)

// Query certificates
let forEmail = db.findCertificates(
    forEmail: "alice@example.com",
    now: Date(),
    requirePrivateKey: true
)

// Get trusted anchors for chain validation
let anchors = db.findTrustedAnchors()
```

### X509CertificateRecord

A metadata wrapper for certificates stored in the database:

```swift
let record = X509CertificateRecord(
    certificate: cert,
    privateKey: key,          // Optional
    isTrusted: true,          // Mark as trust anchor
    algorithms: [.aes256cbc]  // S/MIME capabilities
)

// Computed properties from certificate
print(record.fingerprint)     // SHA-256 fingerprint
print(record.subjectEmail)    // Email from subject/SAN
print(record.keyUsage)        // Key usage flags
print(record.isValid)         // Validity check
print(record.isAnchor)        // Is trusted CA?
```

### X509ChainValidator

RFC 5280-compliant certificate chain validation:

```swift
let validator = X509ChainValidator()

// Validate against explicit trust roots
let result = await validator.validate(
    leaf: userCertificate,
    intermediates: [intermediateCert],
    trustRoots: CertificateStore([rootCA])
)

if result.isValid {
    print("Certificate chain is valid")
    print("Chain: \(result.chain!)")
} else {
    print("Validation failed: \(result.error!)")
}

// Validate using a certificate database
let dbResult = await validator.validate(
    leaf: userCertificate,
    database: db
)
```

## Security Features

### Private Key Encryption at Rest

Private keys stored in `SqliteCertificateDatabase` are encrypted using:

- **Key Derivation**: PBKDF2-HMAC-SHA256 with 100,000 iterations
- **Encryption**: AES-256-GCM (authenticated encryption)
- **Random Salt**: 32 bytes per key
- **Random Nonce**: 12 bytes per encryption

```swift
// Database password protects all private keys
let db = try SqliteCertificateDatabase(
    path: dbPath,
    password: "strong-password-here"
)

// Wrong password = private keys not accessible
let wrongDb = try SqliteCertificateDatabase(
    path: dbPath,
    password: "wrong-password"
)
let record = wrongDb.find(fingerprint: fingerprint)
print(record?.hasPrivateKey)  // false - decryption failed
```

### Chain Validation

The validator performs RFC 5280 checks including:

- Signature verification at each level
- Validity period (not expired, not yet valid)
- Basic constraints (CA certificates, path length)
- Key usage constraints
- Name chaining (issuer matches subject)
- Trust anchor verification

```swift
// Detailed error information
if case .expired(let cert, let expiredAt) = result.error {
    print("\(cert) expired at \(expiredAt)")
}

if case .noTrustAnchor = result.error {
    print("Certificate chain does not end at trusted root")
}
```

## Platform Requirements

Certificate management features require:

| Platform | Minimum Version |
|----------|-----------------|
| macOS    | 11.0+           |
| iOS      | 14.0+           |
| tvOS     | 14.0+           |
| watchOS  | 7.0+            |
| Linux    | Swift 5.9+      |

## Database Schema

The `SqliteCertificateDatabase` uses the following schema:

```sql
CREATE TABLE CERTIFICATES (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    TRUSTED INTEGER NOT NULL DEFAULT 0,
    ANCHOR INTEGER NOT NULL DEFAULT 0,
    BASICCONSTRAINTS INTEGER NOT NULL DEFAULT -1,
    KEYUSAGE INTEGER NOT NULL DEFAULT 0,
    NOTBEFORE INTEGER NOT NULL,
    NOTAFTER INTEGER NOT NULL,
    ISSUERNAME TEXT NOT NULL,
    SERIALNUMBER TEXT NOT NULL,
    SUBJECTNAME TEXT NOT NULL,
    SUBJECTKEYIDENTIFIER TEXT,
    SUBJECTEMAIL TEXT,
    SUBJECTDNSNAMES TEXT,
    FINGERPRINT TEXT NOT NULL UNIQUE,
    ALGORITHMS TEXT,
    ALGORITHMSUPDATED INTEGER NOT NULL DEFAULT 0,
    CERTIFICATE BLOB NOT NULL,
    PRIVATEKEY BLOB
);
```

Indexes are created on `FINGERPRINT`, `SUBJECTEMAIL`, `TRUSTED`, and validity dates
for efficient querying.

## Known Limitations

### RSA Private Key Serialization

RSA private keys cannot currently be round-tripped through the encryption system due
to format differences in swift-certificates' PEM serialization. EC keys (P-256, P-384,
P-521) work correctly.

**Workaround**: For RSA keys, consider using platform-specific keychain storage or
store RSA certificates without private keys in the database.

### Revocation Checking

Certificate revocation checking (CRL and OCSP) is not yet supported. The underlying
swift-certificates library does not currently provide CRL/OCSP support.

**Impact**: Revoked certificates will validate as trusted unless manually removed
from the trust store.

### Cross-Platform Encryption

While certificate management works on all platforms, S/MIME encryption/decryption
requires macOS due to dependencies on CMSEncoder/CMSDecoder.

## Best Practices

### Secure Password Storage

Never hardcode database passwords. Use secure storage:

```swift
// iOS/macOS: Use Keychain
let password = try KeychainService.retrievePassword(for: "cert-db")
let db = try SqliteCertificateDatabase(path: path, password: password)
```

### Certificate Rotation

Monitor certificate expiration and rotate before expiry:

```swift
let expiringRecords = db.find { record in
    let daysToExpiry = record.notAfter.timeIntervalSinceNow / (24 * 60 * 60)
    return daysToExpiry < 30 && daysToExpiry > 0
}

for record in expiringRecords {
    print("Certificate expiring soon: \(record.subjectEmail ?? record.subjectName)")
}
```

### Trust Anchor Management

Only mark root CA certificates as trusted anchors:

```swift
// Correct: Trust only the root CA
let rootRecord = X509CertificateRecord(
    certificate: rootCA,
    isTrusted: true  // This is a trust anchor
)

// Add intermediate as non-trusted (for chain building)
let intermediateRecord = X509CertificateRecord(
    certificate: intermediate,
    isTrusted: false  // Not a trust anchor
)
```

## Topics

### Certificate Storage

- ``X509CertificateStore``
- ``X509CertificateRecord``
- ``X509CertificateDatabaseProtocol``
- ``SqliteCertificateDatabase``

### Chain Validation

- ``X509ChainValidator``
- ``ChainValidationResult``
- ``ChainValidationError``

### Supporting Types

- ``X509KeyUsageFlags``
- ``X509CertificateRecordFields``
- ``EncryptionAlgorithm``
- ``X509CertificateChain``

### Private Key Security

- ``PrivateKeyEncryption``
- ``PrivateKeyEncryptionError``
