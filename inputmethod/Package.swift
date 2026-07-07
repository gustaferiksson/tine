// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TineIME",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "TineIME", path: "Sources/TineIME")
    ]
)
