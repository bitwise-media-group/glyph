// swift-tools-version: 6.0
// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import PackageDescription

// Two Foundation-only libraries, so both build and test on Linux CI:
//   LibreKit  — the FreeStyle Libre 2 (EU) protocol: sensor types, CRC, crypto,
//               FRAM and BLE frame parsing, factory calibration, trend.
//   GlyphCore — app logic with no Apple UI frameworks: units and formatting,
//               reading dedupe/back-fill, statistics, the alert engine, and
//               the widget snapshot.
// The iOS app and widget extension (App/, built from project.yml) depend on both.
let package = Package(
    name: "Glyph",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LibreKit", targets: ["LibreKit"]),
        .library(name: "GlyphCore", targets: ["GlyphCore"]),
    ],
    targets: [
        .target(
            name: "LibreKit",
            path: "Sources/LibreKit"
        ),
        .target(
            name: "GlyphCore",
            dependencies: ["LibreKit"],
            path: "Sources/GlyphCore"
        ),
        .testTarget(
            name: "LibreKitTests",
            dependencies: ["LibreKit"],
            path: "Tests/LibreKitTests"
        ),
        .testTarget(
            name: "GlyphCoreTests",
            dependencies: ["GlyphCore"],
            path: "Tests/GlyphCoreTests"
        ),
    ]
)
