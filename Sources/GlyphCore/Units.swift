// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

/// The unit glucose is shown in. Everything is stored in mg/dL; this only
/// affects display and input.
public enum GlucoseUnit: String, Sendable, Codable, CaseIterable, Identifiable {
    case mmolL
    case mgdL

    public static let mgdLPerMmolL = 18.0182

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .mmolL: "mmol/L"
        case .mgdL: "mg/dL"
        }
    }

    /// Fraction digits shown for a value.
    public var fractionDigits: Int { self == .mmolL ? 1 : 0 }

    /// The smallest step offered when editing thresholds.
    public var step: Double { self == .mmolL ? 0.1 : 1 }

    public func value(fromMgdL mgdL: Double) -> Double {
        switch self {
        case .mmolL: mgdL / Self.mgdLPerMmolL
        case .mgdL: mgdL
        }
    }

    public func mgdL(from value: Double) -> Double {
        switch self {
        case .mmolL: value * Self.mgdLPerMmolL
        case .mgdL: value
        }
    }

    /// The value for display: "5.6" / "101", or "LO" / "HI" outside the
    /// sensor's reporting range.
    public func format(mgdL: Double, withUnit: Bool = false) -> String {
        if mgdL < ReportingRange.lowest { return "LO" }
        if mgdL > ReportingRange.highest { return "HI" }
        let number = Self.number(value(fromMgdL: mgdL), fractionDigits: fractionDigits)
        return withUnit ? "\(number) \(symbol)" : number
    }

    /// A signed change, such as "+0.3" or "−5"; zero has no sign.
    public func formatDelta(mgdL delta: Double) -> String {
        let value = value(fromMgdL: delta)
        let rounded = Self.number(abs(value), fractionDigits: fractionDigits)
        if Double(rounded) == 0 { return rounded }
        return (value > 0 ? "+" : "\u{2212}") + rounded
    }

    /// Locale-independent fixed-point formatting (the widget and Live
    /// Activity show the same string as the app).
    static func number(_ value: Double, fractionDigits: Int) -> String {
        let scale = pow(10, Double(fractionDigits))
        let rounded = (value * scale).rounded() / scale
        if fractionDigits == 0 { return String(Int(rounded)) }
        let whole = Int(rounded.magnitude)
        let fraction = Int(((rounded.magnitude - Double(whole)) * scale).rounded())
        let sign = rounded < 0 ? "-" : ""
        let digits = String(fraction)
        let padded = String(repeating: "0", count: max(0, fractionDigits - digits.count)) + digits
        return "\(sign)\(whole).\(padded)"
    }
}

/// The range the sensor reports; values outside show as LO/HI.
public enum ReportingRange {
    public static let lowest = 40.0
    public static let highest = 500.0
}

/// The target range, in mg/dL.
public struct TargetRange: Sendable, Hashable, Codable {
    public var lower: Double
    public var upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }

    /// The international consensus range, 70–180 mg/dL (3.9–10.0 mmol/L).
    public static let standard = TargetRange(lower: 70, upper: 180)

    public func contains(_ mgdL: Double) -> Bool { (lower...upper).contains(mgdL) }
}

/// How a value relates to the target range, for colouring.
public enum GlucoseLevel: String, Sendable, Codable {
    case urgentLow
    case low
    case inRange
    case high

    public init(mgdL: Double, target: TargetRange, urgentLow: Double = 54) {
        if mgdL < urgentLow {
            self = .urgentLow
        } else if mgdL < target.lower {
            self = .low
        } else if mgdL > target.upper {
            self = .high
        } else {
            self = .inRange
        }
    }
}
