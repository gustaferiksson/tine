// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "tine",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "tine", path: "Sources/tine")
    ]
)
