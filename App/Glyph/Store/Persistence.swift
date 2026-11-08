// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([GlucoseReading.self, Sensor.self])

    /// The store lives in the App Group container so a future extension
    /// (intents, a watch companion) can open it.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration =
            inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(
                schema: schema, url: AppGroup.containerURL.appending(path: "Glyph.store"), cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the Glyph store: \(error)")
        }
    }
}
