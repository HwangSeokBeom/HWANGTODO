// swift-tools-version: 6.2
import PackageDescription

// Shared foundation for the HWANGTODO app + widget extension.
//
//  * HWANGTODOCore   — models, SwiftData stack, deep links, terminology,
//                      parsers, system-surface status. No UI.
//  * HWANGTODODesign — design tokens and reusable SwiftUI components.
//
// Both ship with MainActor-by-default isolation (Approachable Concurrency);
// pure data types opt out with explicit `nonisolated`.
let package = Package(
    name: "HWANGTODOKit",
    defaultLocalization: "ko",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "HWANGTODOCore", targets: ["HWANGTODOCore"]),
        .library(name: "HWANGTODODesign", targets: ["HWANGTODODesign"]),
    ],
    targets: [
        .target(
            name: "HWANGTODOCore",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "HWANGTODODesign",
            dependencies: ["HWANGTODOCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "HWANGTODOCoreTests",
            dependencies: ["HWANGTODOCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
