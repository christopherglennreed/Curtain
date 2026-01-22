// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Curtain",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Curtain", targets: ["Curtain"])
    ],
    targets: [
        .executableTarget(
            name: "Curtain",
            path: "Sources/Curtain",
            resources: [.process("Resources")],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
