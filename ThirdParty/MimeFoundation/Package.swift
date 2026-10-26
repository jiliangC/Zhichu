// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "MimeFoundation", platforms: [.macOS(.v14)],
    products: [.library(name: "MimeFoundation", targets: ["MimeFoundation"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0")
    ], targets: [.target(name: "MimeFoundation", dependencies: [
        .product(name: "Crypto", package: "swift-crypto"), .product(name: "_CryptoExtras", package: "swift-crypto"),
        .product(name: "X509", package: "swift-certificates")])])
