// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pirate",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Pirate",
            dependencies: ["Yams"],
            path: "Sources/Pirate"
        )
    ]
)
