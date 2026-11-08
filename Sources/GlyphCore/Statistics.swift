// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

/// Summary statistics over a period, following the international consensus
/// on time in range (Battelino et al., Diabetes Care 2019).
///
/// Times are fractions of readings, which equal fractions of time because
/// the sensor reports at a fixed interval.
public struct GlucoseStatistics: Sendable, Hashable {
    public let count: Int
    /// Mean glucose, mg/dL.
    public let mean: Double
    /// Standard deviation, mg/dL.
    public let standardDeviation: Double
    /// Coefficient of variation, percent. Under 36 % is considered stable.
    public var coefficientOfVariation: Double { mean > 0 ? standardDeviation / mean * 100 : 0 }
    /// Glucose management indicator, percent (an estimated HbA1c):
    /// 3.31 + 0.02392 × mean mg/dL.
    public var gmi: Double { 3.31 + 0.02392 * mean }
    /// GMI in mmol/mol (IFCC): 12.71 + 4.70587 × mean mmol/L.
    public var gmiMmolPerMol: Double { 12.71 + 4.70587 * (mean / GlucoseUnit.mgdLPerMmolL) }

    /// Below 54 mg/dL.
    public let veryLow: Double
    /// 54–69 mg/dL.
    public let low: Double
    /// Within the target range.
    public let inRange: Double
    /// Above the target, up to 250 mg/dL.
    public let high: Double
    /// Above 250 mg/dL.
    public let veryHigh: Double

    /// Time below range: `veryLow + low`.
    public var belowRange: Double { veryLow + low }
    /// Time above range: `high + veryHigh`.
    public var aboveRange: Double { high + veryHigh }

    public static let veryLowThreshold = 54.0
    public static let veryHighThreshold = 250.0

    /// `nil` for an empty set of values.
    public init?(mgdL values: [Double], target: TargetRange = .standard) {
        guard !values.isEmpty else { return nil }
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count
        let variance =
            values.count > 1
            ? values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (count - 1)
            : 0
        func fraction(_ predicate: (Double) -> Bool) -> Double {
            Double(values.count(where: predicate)) / count
        }
        self.count = values.count
        self.mean = mean
        standardDeviation = variance.squareRoot()
        veryLow = fraction { $0 < Self.veryLowThreshold }
        low = fraction { $0 >= Self.veryLowThreshold && $0 < target.lower }
        inRange = fraction { target.contains($0) }
        high = fraction { $0 > target.upper && $0 <= Self.veryHighThreshold }
        veryHigh = fraction { $0 > max(target.upper, Self.veryHighThreshold) }
    }
}

/// One slot of an ambulatory glucose profile: percentiles of every reading
/// that fell in this time of day across the period.
public struct AGPBucket: Sendable, Hashable, Identifiable {
    /// Minutes after midnight at the start of the slot.
    public let minuteOfDay: Int
    public let p5: Double
    public let p25: Double
    public let median: Double
    public let p75: Double
    public let p95: Double

    public var id: Int { minuteOfDay }
}

public enum AGPProfile {
    /// Buckets readings by time of day (`slotMinutes` wide) and returns the
    /// 5th/25th/50th/75th/95th percentiles of each slot that has at least
    /// `minimumCount` readings.
    public static func compute(
        _ readings: [(date: Date, mgdL: Double)],
        slotMinutes: Int = 30,
        minimumCount: Int = 3,
        calendar: Calendar = .current
    ) -> [AGPBucket] {
        var slots: [Int: [Double]] = [:]
        for reading in readings {
            let parts = calendar.dateComponents([.hour, .minute], from: reading.date)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            slots[minute / slotMinutes * slotMinutes, default: []].append(reading.mgdL)
        }
        return slots.keys.sorted().compactMap { minute in
            let values = slots[minute]!.sorted()
            guard values.count >= minimumCount else { return nil }
            return AGPBucket(
                minuteOfDay: minute,
                p5: percentile(values, 0.05),
                p25: percentile(values, 0.25),
                median: percentile(values, 0.5),
                p75: percentile(values, 0.75),
                p95: percentile(values, 0.95))
        }
    }

    /// Linear-interpolated percentile of sorted values.
    public static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard let first = sorted.first else { return .nan }
        guard sorted.count > 1 else { return first }
        let position = p * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let weight = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * weight
    }
}
