// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Claude2xUsage",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Claude2xUsage",
            path: "Sources/Claude2xUsage",
            exclude: ["Info.plist"]
        )
    ]
)
