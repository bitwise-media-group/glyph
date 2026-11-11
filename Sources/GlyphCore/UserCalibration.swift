// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit

/// A finger-prick blood glucose value paired with what the sensor read at
/// the same moment, before any user calibration (the factory value).
public struct CalibrationPoint: Sendable, Hashable, Codable {
    public var date: Date
    public var bloodMgdL: Double
    public var sensorMgdL: Double

    public init(date: Date, bloodMgdL: Double, sensorMgdL: Double) {
        self.date = date
        self.bloodMgdL = bloodMgdL
        self.sensorMgdL = sensorMgdL
    }
}

/// A straight-line correction on top of the factory value:
/// `calibrated = slope × factory + offset`.
public struct LinearCorrection: Sendable, Hashable, Codable {
    public var slope: Double
    public var offset: Double

    public init(slope: Double, offset: Double) {
        self.slope = slope
        self.offset = offset
    }

    public static let identity = LinearCorrection(slope: 1, offset: 0)

    /// The corrected value, rounded to whole mg/dL like the factory value,
    /// and never negative.
    public func apply(_ mgdL: Double) -> Double {
        max(0, (slope * mgdL + offset).rounded())
    }
}

/// The optional finger-prick calibration.
///
/// The factory calibration stays the source of every reading; this only
/// corrects it when the user has entered blood values for the sensor. The
/// fit is deliberately conservative:
///
/// - Only points from the last ``window`` (measured back from the newest)
///   count, and newer ones weigh more (half-life ``halfLife``), because a
///   sensor's error drifts over its wear.
/// - One point, or points whose sensor values sit close together, give an
///   offset only (slope 1): a slope from a narrow spread is mostly noise.
/// - Points spread at least ``minimumSpread`` apart give a weighted
///   least-squares line, with the slope held to ``slopeRange``.
public enum UserCalibration {
    /// Blood values accepted on entry, in mg/dL (2.2–22.2 mmol/L): wider
    /// than any real finger-prick, narrow enough to catch a unit mix-up.
    public static let bloodRange: ClosedRange<Double> = 40...400
    /// How far back from the newest point others still count.
    public static let window: TimeInterval = 4 * 86_400
    /// A point this much older than the newest weighs half as much.
    public static let halfLife: TimeInterval = 2 * 86_400
    /// The sensor-value spread, in mg/dL, needed before fitting a slope
    /// (2 mmol/L).
    public static let minimumSpread = 36.0
    public static let slopeRange: ClosedRange<Double> = 0.7...1.5
    /// How close a stored reading must be to the finger-prick to pair with it.
    public static let pairingTolerance: TimeInterval = 5 * 60
    /// Above this rate of change (mg/dL per minute) a finger-prick and the
    /// sensor's interstitial value disagree for reasons that aren't the
    /// sensor's error. It's the edge of a flat trend arrow.
    public static let steadyRate = 1.0

    /// The correction for `points`, or `nil` when there are none.
    public static func fit(_ points: [CalibrationPoint]) -> LinearCorrection? {
        guard let newest = points.map(\.date).max() else { return nil }
        let weighted = points.compactMap { point -> (point: CalibrationPoint, weight: Double)? in
            let age = newest.timeIntervalSince(point.date)
            guard age <= window else { return nil }
            return (point, pow(0.5, age / halfLife))
        }
        let total = weighted.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        let meanSensor = weighted.reduce(0) { $0 + $1.weight * $1.point.sensorMgdL } / total
        let meanBlood = weighted.reduce(0) { $0 + $1.weight * $1.point.bloodMgdL } / total

        let sensorValues = weighted.map(\.point.sensorMgdL)
        let spread = (sensorValues.max() ?? 0) - (sensorValues.min() ?? 0)
        guard weighted.count >= 2, spread >= minimumSpread else {
            return LinearCorrection(slope: 1, offset: meanBlood - meanSensor)
        }

        var covariance = 0.0
        var variance = 0.0
        for (point, weight) in weighted {
            covariance += weight * (point.sensorMgdL - meanSensor) * (point.bloodMgdL - meanBlood)
            variance += weight * (point.sensorMgdL - meanSensor) * (point.sensorMgdL - meanSensor)
        }
        let fitted = variance > 0 ? covariance / variance : 1
        let slope = min(slopeRange.upperBound, max(slopeRange.lowerBound, fitted))
        return LinearCorrection(slope: slope, offset: meanBlood - slope * meanSensor)
    }

    /// The sensor's value at `date`, interpolated between the stored
    /// readings either side, or the nearest one when `date` is past the
    /// ends; `nil` when nothing is within ``pairingTolerance``.
    public static func sensorValue(at date: Date, readings: [(date: Date, mgdL: Double)]) -> Double? {
        let near = readings.filter { abs($0.date.timeIntervalSince(date)) <= pairingTolerance }
        let before = near.filter { $0.date <= date }.max { $0.date < $1.date }
        let after = near.filter { $0.date >= date }.min { $0.date < $1.date }
        switch (before, after) {
        case let (before?, after?):
            let span = after.date.timeIntervalSince(before.date)
            guard span > 0 else { return before.mgdL }
            let fraction = date.timeIntervalSince(before.date) / span
            return before.mgdL + fraction * (after.mgdL - before.mgdL)
        case let (before?, nil): return before.mgdL
        case let (nil, after?): return after.mgdL
        case (nil, nil): return nil
        }
    }

    /// The rate of change around `date`, in mg/dL per minute, from the
    /// readings in the quarter-hour up to it.
    public static func rate(at date: Date, readings: [(date: Date, mgdL: Double)]) -> Double? {
        Trend.rate(of: readings.filter { $0.date <= date.addingTimeInterval(60) })
    }

    /// Whether glucose was steady enough at that rate for a useful point.
    public static func isSteady(rate: Double?) -> Bool {
        guard let rate else { return true }
        return abs(rate) < steadyRate
    }
}

extension GlucoseSample {
    /// This sample with `correction` applied to its value.
    public func corrected(by correction: LinearCorrection?) -> GlucoseSample {
        guard let correction else { return self }
        return GlucoseSample(
            sensorAge: sensorAge, date: date, mgdL: correction.apply(mgdL), raw: raw, rawTemperature: rawTemperature,
            kind: kind)
    }
}
