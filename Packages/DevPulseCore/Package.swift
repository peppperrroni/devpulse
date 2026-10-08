// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DevPulseCore",
    platforms: [.macOS(.v26)],
    products: [.library(name: "DevPulseCore", targets: ["DevPulseCore"])],
    targets: [
        .target(name: "DevPulseCore"),
        .testTarget(name: "DevPulseCoreTests", dependencies: ["DevPulseCore"]),
    ]
)
