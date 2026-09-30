// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Calamus",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Calamus",
            path: "Sources/Calamus"
        )
    ]
)
