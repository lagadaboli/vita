// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VITA",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VITACore", targets: ["VITACore"]),
        .library(name: "HealthKitBridge", targets: ["HealthKitBridge"]),
        .library(name: "ConsumptionBridge", targets: ["ConsumptionBridge"]),
        .library(name: "IntentionalityTracker", targets: ["IntentionalityTracker"]),
        .library(name: "CausalityEngine", targets: ["CausalityEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    ],
    targets: [
        // MARK: - Core
        .target(
            name: "VITACore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/VITACore"
        ),

        // MARK: - Layer 2: HealthKit Bridge (Primary Focus)
        .target(
            name: "HealthKitBridge",
            dependencies: ["VITACore"],
            path: "Sources/HealthKitBridge"
        ),

        // MARK: - Layer 1: Consumption Bridge (Stub)
        .target(
            name: "ConsumptionBridge",
            dependencies: ["VITACore"],
            path: "Sources/ConsumptionBridge"
        ),

        // MARK: - Layer 3: Intentionality Tracker (Stub)
        .target(
            name: "IntentionalityTracker",
            dependencies: ["VITACore"],
            path: "Sources/IntentionalityTracker"
        ),

        // MARK: - Causality Engine (Stub)
        .target(
            name: "CausalityEngine",
            dependencies: ["VITACore"],
            path: "Sources/CausalityEngine"
        ),

        // MARK: - Tests
        .testTarget(
            name: "VITACoreTests",
            dependencies: ["VITACore"],
            path: "Tests/VITACoreTests"
        ),
        .testTarget(
            name: "HealthKitBridgeTests",
            dependencies: ["HealthKitBridge"],
            path: "Tests/HealthKitBridgeTests"
        ),
    ]
)
