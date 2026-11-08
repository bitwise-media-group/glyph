// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

/// A calibrated glucose value with its wall-clock time.
public struct GlucoseSample: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable {
        /// One-minute data (BLE trend records, FRAM trend ring).
        case trend
        /// Fifteen-minute data (BLE history records, FRAM history ring).
        case history
    }

    public let sensorAge: Int
    public let date: Date
    public let mgdL: Double
    public let raw: Int
    public let rawTemperature: Int
    public let kind: Kind

    public init(sensorAge: Int, date: Date, mgdL: Double, raw: Int, rawTemperature: Int, kind: Kind) {
        self.sensorAge = sensorAge
        self.date = date
        self.mgdL = mgdL
        self.raw = raw
        self.rawTemperature = rawTemperature
        self.kind = kind
    }
}

/// Maps sensor ages (minutes since start) to wall-clock dates.
///
/// The preferred clock is the sensor's own: `start + age`. It is immune to
/// late delivery (a frame that sat in a buffer, or arrived after a
/// reconnect) because the age travels inside the frame. The arrival time is
/// the cross-check: when `start + frameAge` and the arrival disagree by more
/// than ``tolerance`` the start date is suspect (the clock changed, or the
/// sensor was re-paired), and the frame is timed from its arrival instead.
public struct SensorClock: Sendable, Hashable {
    public static let tolerance: TimeInterval = 120

    /// When the sensor started, if known.
    public let startDate: Date?

    public init(startDate: Date?) {
        self.startDate = startDate
    }

    /// The start date implied by a frame of age `age` arriving at `arrival`.
    public static func startDate(age: Int, arrival: Date) -> Date {
        arrival.addingTimeInterval(-Double(age) * 60)
    }

    /// Whether the start-anchored clock agrees with this arrival.
    public func agrees(frameAge: Int, arrival: Date) -> Bool {
        guard let startDate else { return false }
        let expected = startDate.addingTimeInterval(Double(frameAge) * 60)
        return abs(expected.timeIntervalSince(arrival)) <= Self.tolerance
    }

    /// The date of a record at `sensorAge`, from a frame of age `frameAge`
    /// that arrived at `arrival`.
    public func date(sensorAge: Int, frameAge: Int, arrival: Date) -> Date {
        if let startDate, agrees(frameAge: frameAge, arrival: arrival) {
            return startDate.addingTimeInterval(Double(sensorAge) * 60)
        }
        return arrival.addingTimeInterval(-Double(frameAge - sensorAge) * 60)
    }
}

/// What one BLE frame means for the app.
public enum FrameOutcome: Sendable, Equatable {
    /// Valid readings, newest first. `current` is the 0-minute record when
    /// it converted.
    case readings(current: GlucoseSample?, samples: [GlucoseSample])
    /// Inside the first hour: show "warming up", store nothing.
    case warmingUp(minutesRemaining: Int)
    /// Past the sensor's wear time, or its values stopped changing.
    case expired
    /// The frame failed a plausibility check and was dropped.
    case rejected(FrameSanity.Verdict)
}

/// Turns a parsed frame into calibrated, timestamped samples, applying the
/// sanity rules, warm-up and expiry.
public struct FrameDecoder: Sendable {
    public let converter: any GlucoseConverter
    public let clock: SensorClock
    public let maxAge: Int

    public init(converter: any GlucoseConverter, clock: SensorClock, maxAge: Int) {
        self.converter = converter
        self.clock = clock
        self.maxAge = maxAge
    }

    public func decode(_ frame: BLEFrame, arrival: Date) -> FrameOutcome {
        if frame.age >= maxAge { return .expired }
        if frame.age < SensorType.warmUpMinutes {
            return .warmingUp(minutesRemaining: SensorType.warmUpMinutes - frame.age)
        }
        switch FrameSanity.check(frame) {
        case .ok: break
        case .stuck: return .expired
        case let verdict: return .rejected(verdict)
        }

        let records =
            frame.trend.map { ($0, GlucoseSample.Kind.trend) }
            + frame.history.map { ($0, GlucoseSample.Kind.history) }
        let samples = records.compactMap { record, kind in
            sample(record, kind: kind, frameAge: frame.age, arrival: arrival)
        }
        .sorted { $0.sensorAge > $1.sensorAge }
        let current = samples.first { $0.kind == .trend && $0.sensorAge == frame.age }
        return .readings(current: current, samples: samples)
    }

    /// Samples from an NFC FRAM read (the last 15 minutes plus up to 8 hours
    /// of history), timed from `scanDate`, for back-filling at pairing.
    public func samples(from fram: FRAM, scanDate: Date) -> [GlucoseSample] {
        let records =
            fram.trend.map { ($0, GlucoseSample.Kind.trend) }
            + fram.history.map { ($0, GlucoseSample.Kind.history) }
        return records.compactMap { record, kind in
            sample(record, kind: kind, frameAge: fram.age, arrival: scanDate)
        }
        .sorted { $0.sensorAge > $1.sensorAge }
    }

    private func sample(_ record: RawReading, kind: GlucoseSample.Kind, frameAge: Int, arrival: Date)
        -> GlucoseSample?
    {
        guard record.isValid, record.sensorAge >= SensorType.warmUpMinutes,
            let mgdL = converter.glucose(for: record)
        else { return nil }
        return GlucoseSample(
            sensorAge: record.sensorAge,
            date: clock.date(sensorAge: record.sensorAge, frameAge: frameAge, arrival: arrival),
            mgdL: mgdL,
            raw: record.raw,
            rawTemperature: record.rawTemperature,
            kind: kind)
    }
}
