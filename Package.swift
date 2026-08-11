// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Miore",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "Miore", targets: ["Miore"])],
    targets: [
        .executableTarget(
            name: "Miore",
            path: "Sources/Miore",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MioreTests", dependencies: ["Miore"], path: "Tests/MioreTests")
    ]
)
