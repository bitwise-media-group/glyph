// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// Turns raw sensor records into glucose in mg/dL.
///
/// ``FactoryCalibration`` is the only implementation, and the protocol keeps
/// it isolated in one file (see NOTICE). The optional finger-prick
/// calibration is not a converter: GlyphCore's `UserCalibration` corrects
/// the factory value afterwards, in the app's pipeline, so the factory value
/// is kept beside the corrected one.
public protocol GlucoseConverter: Sendable {
    /// Glucose in mg/dL, or `nil` when the record can't be converted.
    func glucose(for reading: RawReading) -> Double?
}

/// Plausibility checks on a frame's records before any of them is used.
public enum FrameSanity {
    /// Raw values above this are electrically implausible; the frame is
    /// dropped.
    public static let maximumRaw = 3000
    /// When at least this many trend records carry the identical raw value
    /// the sensor has stopped measuring (typically after expiry).
    public static let repeatedValueLimit = 5

    public enum Verdict: Equatable, Sendable {
        case ok
        /// A raw value above ``maximumRaw``: drop the frame.
        case implausibleRaw(Int)
        /// ``repeatedValueLimit`` or more identical trend values: treat the
        /// sensor as expired.
        case stuck(Int)
    }

    public static func check(_ frame: BLEFrame) -> Verdict {
        let valid = frame.records.filter(\.isValid)
        if let high = valid.map(\.raw).max(), high > maximumRaw { return .implausibleRaw(high) }
        let counts = Dictionary(grouping: frame.trend.filter(\.isValid), by: \.raw).mapValues(\.count)
        if let (raw, count) = counts.max(by: { $0.value < $1.value }), count >= repeatedValueLimit {
            return .stuck(raw)
        }
        return .ok
    }
}
