// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenshotGenerator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ScreenshotGenerator"),
    ]
)
