// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownReader",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MarkdownReader",
            path: "Sources/MarkdownReader"
        )
    ]
)
