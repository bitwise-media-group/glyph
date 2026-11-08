// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import ActivityKit
import Foundation
import GlyphCore
import LibreKit

/// The Live Activity: Lock Screen, Dynamic Island, and the iPhone Duo's
/// outer display when folded. The app updates it on every reading.
nonisolated struct GlucoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var mgdL: Double?
        var date: Date
        var trend: TrendArrow
        var deltaMgdL: Double?
        var unit: GlucoseUnit
        var target: TargetRange
        /// The last hour at five-minute resolution, oldest first, for the
        /// expanded sparkline (kept small: an update must stay under 4 KB).
        var recent: [WidgetSnapshot.Point]
    }

    var sensorSerial: String
    var expiry: Date?
}
