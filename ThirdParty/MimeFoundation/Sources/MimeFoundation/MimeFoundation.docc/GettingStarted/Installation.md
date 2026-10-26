# Installation

Add MimeFoundation to your Swift project.

## Overview

MimeFoundation is distributed as a Swift Package and can be added to your project using Swift Package Manager.

## Adding MimeFoundation to Your Project

### Using Xcode

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the repository URL for MimeFoundation
3. Select the version rule (recommended: "Up to Next Major Version")
4. Click **Add Package**

### Using Package.swift

Add MimeFoundation to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/example/MimeFoundation.git", from: "1.0.0")
]
```

Then add it to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["MimeFoundation"]
)
```

## Platform Requirements

MimeFoundation supports the following platforms:

| Platform | Minimum Version | S/MIME Support |
|----------|-----------------|----------------|
| macOS    | 10.15           | 11.0+          |
| iOS      | 13.0            | 14.0+          |
| tvOS     | 13.0            | 14.0+          |
| watchOS  | 6.0             | 7.0+           |

> Note: S/MIME cryptographic features require newer platform versions due to dependencies on CryptoKit and the Swift Certificates library.

## Importing the Module

Once installed, import MimeFoundation in your Swift files:

```swift
import MimeFoundation
```

## Verifying Your Installation

Create a simple test to verify everything is working:

```swift
import MimeFoundation

let message = MimeMessage()
message.subject = "Test"
print("MimeFoundation is working!")
```

## Topics

### Next Steps

- <doc:QuickStart>
