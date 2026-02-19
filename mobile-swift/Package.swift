// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VITA",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "VITACore", targets: ["VITACore"]),
        .library(name: "VITADesignSystem", targets: ["VITADesignSystem"]),
        .library(name: "CausalityEngine", targets: ["CausalityEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        .target(
            name: "VITACore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/VITACore"
        ),
        .target(
            name: "VITADesignSystem",
            dependencies: ["VITACore"],
            path: "Sources/VITADesignSystem"
        ),
        .target(
            name: "CausalityEngine",
            dependencies: ["VITACore"],
            path: "Sources/CausalityEngine"
        ),
        .testTarget(
            name: "VITACoreTests",
            dependencies: ["VITACore"],
            path: "Tests/VITACoreTests"
        ),
    ]
)
