// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

/// The direction-and-speed arrow shown next to the current value.
public enum TrendArrow: String, Sendable, Codable, CaseIterable {
    case risingQuickly
    case rising
    case risingSlightly
    case flat
    case fallingSlightly
    case falling
    case fallingQuickly
    case unknown

    /// Buckets a rate of change in mg/dL per minute by its magnitude: under 1
    /// is flat, 1–2 slight, 2–3 a full arrow, 3 or more quick.
    public init(rate: Double?) {
        guard let rate, rate.isFinite else {
            self = .unknown
            return
        }
        let rising = rate > 0
        switch abs(rate) {
        case 3...: self = rising ? .risingQuickly : .fallingQuickly
        case 2..<3: self = rising ? .rising : .falling
        case 1..<2: self = rising ? .risingSlightly : .fallingSlightly
        default: self = .flat
        }
    }

    public var symbol: String {
        switch self {
        case .risingQuickly: "⇈"
        case .rising: "↑"
        case .risingSlightly: "↗"
        case .flat: "→"
        case .fallingSlightly: "↘"
        case .falling: "↓"
        case .fallingQuickly: "⇊"
        case .unknown: "–"
        }
    }

    /// An SF Symbols name for the arrow.
    public var systemImage: String {
        switch self {
        case .risingQuickly: "chevron.up.2"
        case .rising: "arrow.up"
        case .risingSlightly: "arrow.up.right"
        case .flat: "arrow.right"
        case .fallingSlightly: "arrow.down.right"
        case .falling: "arrow.down"
        case .fallingQuickly: "chevron.down.2"
        case .unknown: "minus"
        }
    }

    public var accessibilityDescription: String {
        switch self {
        case .risingQuickly: "rising quickly"
        case .rising: "rising"
        case .risingSlightly: "rising slightly"
        case .flat: "steady"
        case .fallingSlightly: "falling slightly"
        case .falling: "falling"
        case .fallingQuickly: "falling quickly"
        case .unknown: "trend unknown"
        }
    }
}

public enum Trend {
    /// The least-squares slope, in mg/dL per minute, of the points within
    /// `window` of the newest one. `nil` with fewer than `minimumPoints`
    /// points or when they span under 4 minutes.
    public static func rate(
        of points: [(date: Date, mgdL: Double)],
        window: TimeInterval = 15 * 60,
        minimumPoints: Int = 3
    ) -> Double? {
        guard let newest = points.map(\.date).max() else { return nil }
        let recent = points.filter { newest.timeIntervalSince($0.date) <= window }
        guard recent.count >= minimumPoints,
            let oldest = recent.map(\.date).min(),
            newest.timeIntervalSince(oldest) >= 4 * 60
        else { return nil }

        let xs = recent.map { $0.date.timeIntervalSince(newest) / 60 }
        let ys = recent.map(\.mgdL)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        var covariance = 0.0
        var variance = 0.0
        for (x, y) in zip(xs, ys) {
            covariance += (x - meanX) * (y - meanY)
            variance += (x - meanX) * (x - meanX)
        }
        guard variance > 0 else { return nil }
        return covariance / variance
    }
}
