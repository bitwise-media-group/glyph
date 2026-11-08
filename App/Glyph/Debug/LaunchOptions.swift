// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore

/// Launch arguments for UI tests, screenshots and debugging. Release builds
/// ignore them all.
enum LaunchOptions {
    /// `-GlyphScenario <name>`: run a fixed `GlucoseScenario` from a
    /// throwaway in-memory store, with Bluetooth, alerts, the Live Activity
    /// and widget updates off, so the user's sensor, data and widgets are
    /// untouched.
    static var scenario: GlucoseScenario? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "GlyphScenario").flatMap(GlucoseScenario.init(rawValue:))
        #else
            nil
        #endif
    }

    /// `-GlyphSection now|history|sensor|settings`: open on that section.
    static var initialSection: AppSection? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "GlyphSection").flatMap(AppSection.init(rawValue:))
        #else
            nil
        #endif
    }

    /// `-GlyphShowReservedRegions`: draw the fold and occlusion regions and
    /// the hinge state over the app.
    static var showsReservedRegions: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-GlyphShowReservedRegions")
        #else
            false
        #endif
    }
}
