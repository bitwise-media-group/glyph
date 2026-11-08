// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore

/// The App Group shared by the app and the widget extension.
nonisolated enum AppGroup {
    static let identifier = "group.uk.co.bitwisemedia.glyph"

    /// The shared container. An unsigned simulator build has no App Group,
    /// so it falls back to the process's own Application Support directory
    /// (the widgets then show placeholders).
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        let fallback = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Reads and writes the widget snapshot in the App Group container.
nonisolated enum SnapshotStore {
    static var url: URL { AppGroup.containerURL.appending(path: "widget-snapshot.json") }

    static func read() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? WidgetSnapshot.decode(data)) ?? .empty
    }

    /// Written with "until first unlock" protection so the widgets can read
    /// it on the Lock Screen.
    static func write(_ snapshot: WidgetSnapshot) throws {
        try snapshot.encoded().write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
