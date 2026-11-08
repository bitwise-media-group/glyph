// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit

/// Decides which incoming samples to store.
///
/// Readings are keyed by the sensor's own minute counter (serial + sensor
/// age), which is exact and unaffected by clock or delivery jitter. Every
/// BLE frame repeats the last 15 minutes and the last three history slots,
/// so most of each frame is already stored; what is left fills gaps, for
/// example after the phone was out of range.
public enum ReadingMerge {
    /// The samples from `incoming` not yet stored, one per sensor age,
    /// newest first. One-minute trend data wins over a history record for
    /// the same minute.
    public static func newSamples(_ incoming: [GlucoseSample], existingAges: Set<Int>) -> [GlucoseSample] {
        var byAge: [Int: GlucoseSample] = [:]
        for sample in incoming where !existingAges.contains(sample.sensorAge) {
            if let kept = byAge[sample.sensorAge], kept.kind == .trend { continue }
            byAge[sample.sensorAge] = sample
        }
        return byAge.values.sorted { $0.sensorAge > $1.sensorAge }
    }

    /// The change from the reading closest to five minutes before `current`
    /// (accepting 3–7 minutes), or `nil` if there is none.
    public static func delta(
        current: (date: Date, mgdL: Double), history: [(date: Date, mgdL: Double)]
    ) -> Double? {
        let target = current.date.addingTimeInterval(-5 * 60)
        let candidates = history.filter {
            let age = current.date.timeIntervalSince($0.date)
            return age >= 3 * 60 && age <= 7 * 60
        }
        guard
            let previous = candidates.min(by: {
                abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
            })
        else { return nil }
        return current.mgdL - previous.mgdL
    }
}

/// Lets an action run at most once per `interval`, such as widget timeline
/// reloads, which iOS budgets.
public struct Throttle: Sendable, Hashable, Codable {
    public let interval: TimeInterval
    public private(set) var lastFired: Date?

    public init(interval: TimeInterval, lastFired: Date? = nil) {
        self.interval = interval
        self.lastFired = lastFired
    }

    /// Whether to run now; records the run when it returns `true`.
    public mutating func shouldFire(at date: Date) -> Bool {
        if let lastFired, date.timeIntervalSince(lastFired) < interval { return false }
        lastFired = date
        return true
    }
}
