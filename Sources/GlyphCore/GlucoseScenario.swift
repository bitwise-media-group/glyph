// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

/// Fixed glucose scenarios for screenshots and UI tests.
///
/// Each scenario ends "now" in a known state: a value and rate of change, or
/// a sensor state. History before that follows a fixed daily pattern, so
/// the same `now` always produces the same readings. The last 16 minutes lie
/// exactly on the scenario's final line, so the app's trend arrow and colour
/// are the ones the scenario names, and over the hour before that the curve
/// eases from the daily pattern to where that line starts.
public enum GlucoseScenario: String, Sendable, CaseIterable {
    case inRange
    case high
    case low
    case urgentLow
    case risingFast
    case fallingFast
    case warmingUp
    case signalLost
    case expired
    case noSensor

    /// Where the story ends: mg/dL now and the rate of change, mg/dL/min.
    public var ending: (mgdL: Double, rate: Double)? {
        switch self {
        case .inRange: (112, 0.2)
        case .high: (262, 0.4)
        case .low: (64, -0.4)
        case .urgentLow: (49, -1.3)
        case .risingFast: (168, 3.4)
        case .fallingFast: (96, -2.4)
        case .signalLost: (128, -0.2)
        case .warmingUp, .expired, .noSensor: nil
        }
    }

    /// How long ago the sensor started, or `nil` for no sensor.
    public var sensorAge: TimeInterval? {
        switch self {
        case .noSensor: nil
        case .warmingUp: 25 * 60
        case .expired: 15 * 86_400
        default: 10 * 86_400
        }
    }

    /// Minutes between the last reading and now (signal lost).
    public var minutesSinceLastReading: Int { self == .signalLost ? 12 : 0 }

    /// Whether the sensor keeps sending readings after launch.
    public var isLive: Bool {
        switch self {
        case .signalLost, .expired, .noSensor: false
        default: true
        }
    }

    /// Glucose at `date` for a story that ends at `now`, in mg/dL.
    public func mgdL(at date: Date, now: Date) -> Double {
        let background = Self.background(at: date)
        guard let ending else { return background }
        let end = now.addingTimeInterval(-Double(minutesSinceLastReading) * 60)
        // The line runs back only to 16 minutes before the end; earlier, the
        // curve aims for where it starts rather than extrapolating a steep
        // slope far back.
        let anchor = max(date, end.addingTimeInterval(-16 * 60))
        let line = ending.mgdL + ending.rate * anchor.timeIntervalSince(end) / 60
        // 0 until 76 minutes before the end, 1 from 16 minutes before.
        let progress = min(max((date.timeIntervalSince(end) + 76 * 60) / (60 * 60), 0), 1)
        let weight = progress * progress * (3 - 2 * progress)
        return Self.clamped(background * (1 - weight) + line * weight)
    }

    /// A day of meals and nights with a little minute-to-minute wobble,
    /// computed from the time alone.
    static func background(at date: Date) -> Double {
        let t = date.timeIntervalSince1970
        let day = 2 * Double.pi * t / 86_400
        let meals = 2 * Double.pi * t / (5 * 3600)
        let minute = Int((t / 60).rounded(.down))
        let wobble = Double((minute &* 2_654_435_761) & 0xFF) / 255 * 6 - 3
        return clamped(128 + 34 * sin(day - 1.2) + 22 * sin(meals) + wobble)
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, 40), 400)
    }
}
