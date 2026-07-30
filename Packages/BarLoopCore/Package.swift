// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BarLoopCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BarLoopCore", targets: ["BarLoopCore"]),
    ],
    targets: [
        .target(name: "BarLoopCore"),
        .testTarget(name: "BarLoopCoreTests", dependencies: ["BarLoopCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
