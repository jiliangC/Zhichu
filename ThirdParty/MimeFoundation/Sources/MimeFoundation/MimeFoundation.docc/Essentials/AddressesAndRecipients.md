# Addresses and Recipients

Work with email addresses and recipient lists.

## Overview

MimeFoundation provides a complete implementation of RFC 5322 email addresses, supporting individual mailboxes, group addresses, and internationalized email addresses (EAI). The addressing system handles parsing, validation, and formatting automatically.

## Address Types

The library defines three address types:

- ``MailboxAddress``: A single email address (e.g., `alice@example.com`)
- ``GroupAddress``: A named group of addresses (e.g., `Team: alice@ex.com, bob@ex.com;`)
- ``InternetAddressList``: A mutable collection of addresses

All address types inherit from ``InternetAddress``, which provides common functionality.

## Creating Mailbox Addresses

The most common address type is ``MailboxAddress``:

```swift
// Simple address
let address1 = MailboxAddress(address: "alice@example.com")

// With display name
let address2 = MailboxAddress(name: "Alice Smith", address: "alice@example.com")

// With name and encoding for international names
let address3 = MailboxAddress(name: "田中太郎", address: "tanaka@example.jp")
```

### Address Components

Access the parts of an address:

```swift
let address = MailboxAddress(name: "Alice Smith", address: "alice@example.com")

print(address.name)     // "Alice Smith"
print(address.address)  // "alice@example.com"
```

## Creating Group Addresses

Group addresses represent distribution lists or named collections:

```swift
let group = GroupAddress(name: "Engineering Team")

// Add members
group.members.add(MailboxAddress(name: "Alice", address: "alice@example.com"))
group.members.add(MailboxAddress(name: "Bob", address: "bob@example.com"))

// The formatted address looks like:
// Engineering Team: alice@example.com, bob@example.com;
```

## Working with Address Lists

Message recipients are stored in ``InternetAddressList`` collections:

```swift
// Add addresses
message.to.add(MailboxAddress(address: "alice@example.com"))
message.to.add(MailboxAddress(name: "Bob", address: "bob@example.com"))

// Add a group
let team = GroupAddress(name: "Team")
team.members.add(MailboxAddress(address: "member1@example.com"))
message.cc.add(team)

// Check if empty
if !message.bcc.isEmpty {
    print("Has BCC recipients")
}

// Count recipients
print("To recipients: \(message.to.count)")
```

### Iterating Over Addresses

```swift
for address in message.to {
    switch address {
    case let mailbox as MailboxAddress:
        print("Mailbox: \(mailbox.address)")
    case let group as GroupAddress:
        print("Group: \(group.name ?? "unnamed")")
        for member in group.members {
            print("  - \(member)")
        }
    default:
        break
    }
}
```

## Parsing Addresses

Parse addresses from strings:

```swift
// Parse a single address
let parsed = try InternetAddress.parse("Alice <alice@example.com>")

// Parse an address list
let list = try InternetAddressList.parse("Alice <a@ex.com>, Bob <b@ex.com>")

// With parser options for lenient parsing
var options = ParserOptions()
options.addressParserComplianceMode = .loose
let lenient = try InternetAddressList.parse(input, options: options)
```

## Formatting Addresses

Convert addresses back to strings:

```swift
let address = MailboxAddress(name: "Alice Smith", address: "alice@example.com")

// Default formatting
print(address.description)  // Alice Smith <alice@example.com>

// With format options
var options = FormatOptions()
options.international = true  // Allow UTF-8 in output
let formatted = address.formatted(options: options)
```

## Internationalized Addresses

MimeFoundation supports internationalized email addresses (EAI):

```swift
// International domain names are handled automatically
let address = MailboxAddress(address: "user@例え.jp")

// The address is encoded using Punycode when needed
// Becomes: user@xn--r8jz45g.jp

// International display names are RFC 2047 encoded
let international = MailboxAddress(name: "田中太郎", address: "tanaka@example.com")
```

## Recipient Address Extraction

Get all recipient addresses from a message:

```swift
// Get all recipients (To, Cc, Bcc)
let recipients = message.getRecipients()

// Iterate over mailbox addresses
for recipient in recipients {
    if let mailbox = recipient as? MailboxAddress {
        print("Send to: \(mailbox.address)")
    }
}
```

## Reply Address Handling

Determine where replies should be sent:

```swift
// Reply-To takes precedence over From
if !message.replyTo.isEmpty {
    for address in message.replyTo {
        print("Reply to: \(address)")
    }
} else {
    for address in message.from {
        print("Reply to: \(address)")
    }
}
```

## Address Validation

While parsing validates syntax, you may want additional checks:

```swift
let address = MailboxAddress(address: "alice@example.com")

// Check for a valid-looking address
let hasAtSign = address.address.contains("@")
let parts = address.address.split(separator: "@")
let hasDomain = parts.count == 2 && !parts[1].isEmpty
```

> Note: Full email validation requires checking DNS records and attempting delivery. Syntax validation only ensures the address conforms to RFC 5322 format.

## Resent Headers

Handle forwarded messages with resent addresses:

```swift
// Set resent headers for forwarding
message.resentFrom.add(MailboxAddress(address: "forwarder@example.com"))
message.resentTo.add(MailboxAddress(address: "newrecipient@example.com"))
message.resentDate = DateTimeOffset.now
message.resentMessageId = MimeUtils.generateMessageId(domain: "example.com")
```

## Complete Example

```swift
let message = MimeMessage()

// Set sender with display name
message.from.add(MailboxAddress(
    name: "Support Team",
    address: "support@company.com"
))

// Set reply-to a different address
message.replyTo.add(MailboxAddress(
    name: "Help Desk",
    address: "helpdesk@company.com"
))

// Add individual recipients
message.to.add(MailboxAddress(
    name: "John Customer",
    address: "john@customer.com"
))

// Add a team as CC
let salesTeam = GroupAddress(name: "Sales")
salesTeam.members.add(MailboxAddress(address: "alice@company.com"))
salesTeam.members.add(MailboxAddress(address: "bob@company.com"))
message.cc.add(salesTeam)

// Add BCC (will be stripped in sent message)
message.bcc.add(MailboxAddress(address: "archive@company.com"))
```

## Topics

### Related Types

- ``InternetAddress``
- ``MailboxAddress``
- ``GroupAddress``
- ``InternetAddressList``

### Related Articles

- <doc:CreatingMessages>
- <doc:ParsingMessages>
