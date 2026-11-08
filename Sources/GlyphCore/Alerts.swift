// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

public enum AlertKind: String, Sendable, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    case urgentLow
    case low
    case high
    case fallingFast
    case risingFast
    case signalLoss

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .urgentLow: "Urgent low"
        case .low: "Low"
        case .high: "High"
        case .fallingFast: "Falling fast"
        case .risingFast: "Rising fast"
        case .signalLoss: "No sensor data"
        }
    }

    /// Urgent low and signal loss break through Focus (time-sensitive, and
    /// critical where the entitlement is granted).
    public var isUrgent: Bool { self == .urgentLow || self == .signalLoss }
}

/// User-configurable thresholds, all in mg/dL (rates in mg/dL per minute).
public struct AlertSettings: Sendable, Hashable, Codable {
    public struct Rule: Sendable, Hashable, Codable {
        public var isEnabled: Bool
        public var threshold: Double
        /// While the condition persists, how long until it alerts again.
        public var repeatInterval: TimeInterval
        /// How long the notification's Snooze action silences it.
        public var snoozeDuration: TimeInterval

        public init(isEnabled: Bool, threshold: Double, repeatInterval: TimeInterval, snoozeDuration: TimeInterval) {
            self.isEnabled = isEnabled
            self.threshold = threshold
            self.repeatInterval = repeatInterval
            self.snoozeDuration = snoozeDuration
        }
    }

    public var urgentLow: Rule
    public var low: Rule
    public var high: Rule
    public var fallingFast: Rule
    public var risingFast: Rule
    /// Minutes without a reading before the signal-loss alert fires.
    public var signalLoss: Rule

    public init(
        urgentLow: Rule, low: Rule, high: Rule, fallingFast: Rule, risingFast: Rule, signalLoss: Rule
    ) {
        self.urgentLow = urgentLow
        self.low = low
        self.high = high
        self.fallingFast = fallingFast
        self.risingFast = risingFast
        self.signalLoss = signalLoss
    }

    public static let defaults = AlertSettings(
        urgentLow: Rule(isEnabled: true, threshold: 55, repeatInterval: 5 * 60, snoozeDuration: 15 * 60),
        low: Rule(isEnabled: true, threshold: 70, repeatInterval: 15 * 60, snoozeDuration: 30 * 60),
        high: Rule(isEnabled: true, threshold: 250, repeatInterval: 60 * 60, snoozeDuration: 60 * 60),
        fallingFast: Rule(isEnabled: false, threshold: 2, repeatInterval: 30 * 60, snoozeDuration: 30 * 60),
        risingFast: Rule(isEnabled: false, threshold: 2, repeatInterval: 30 * 60, snoozeDuration: 30 * 60),
        signalLoss: Rule(isEnabled: true, threshold: 20, repeatInterval: 0, snoozeDuration: 0))

    public subscript(kind: AlertKind) -> Rule {
        get {
            switch kind {
            case .urgentLow: urgentLow
            case .low: low
            case .high: high
            case .fallingFast: fallingFast
            case .risingFast: risingFast
            case .signalLoss: signalLoss
            }
        }
        set {
            switch kind {
            case .urgentLow: urgentLow = newValue
            case .low: low = newValue
            case .high: high = newValue
            case .fallingFast: fallingFast = newValue
            case .risingFast: risingFast = newValue
            case .signalLoss: signalLoss = newValue
            }
        }
    }
}

/// What the engine remembers between readings. Persist it so a relaunch
/// doesn't re-alert or forget a snooze.
public struct AlertState: Sendable, Hashable, Codable {
    public var lastFired: [AlertKind: Date] = [:]
    public var snoozedUntil: [AlertKind: Date] = [:]
    /// Conditions true at the last evaluation.
    public var active: Set<AlertKind> = []

    public init() {}

    public func isSnoozed(_ kind: AlertKind, at date: Date) -> Bool {
        (snoozedUntil[kind].map { $0 > date }) ?? false
    }
}

/// An alert to deliver.
public struct AlertEvent: Sendable, Hashable {
    public let kind: AlertKind
    public let mgdL: Double
    public let rate: Double?
    public let date: Date
}

/// Pure evaluation of each new reading against the alert rules.
///
/// An alert fires when its condition becomes true, then repeats every
/// `repeatInterval` while it stays true. Snoozing silences one kind until a
/// time. When a condition clears, the next occurrence alerts immediately.
/// Urgent low suppresses low, and a level alert suppresses the rate alert in
/// the same direction (a falling-fast alert while already low adds nothing).
public struct AlertEngine: Sendable {
    public var settings: AlertSettings

    public init(settings: AlertSettings) {
        self.settings = settings
    }

    /// The conditions true for this reading, before snoozes and repeats.
    public func conditions(mgdL: Double, rate: Double?) -> Set<AlertKind> {
        var result: Set<AlertKind> = []
        if settings.urgentLow.isEnabled, mgdL < settings.urgentLow.threshold {
            result.insert(.urgentLow)
        } else if settings.low.isEnabled, mgdL < settings.low.threshold {
            result.insert(.low)
        }
        if settings.high.isEnabled, mgdL > settings.high.threshold { result.insert(.high) }
        if let rate {
            let isLow = result.contains(.urgentLow) || result.contains(.low)
            if settings.fallingFast.isEnabled, rate <= -settings.fallingFast.threshold, !isLow {
                result.insert(.fallingFast)
            }
            if settings.risingFast.isEnabled, rate >= settings.risingFast.threshold, !result.contains(.high) {
                result.insert(.risingFast)
            }
        }
        return result
    }

    /// Evaluates a reading, updating `state`, and returns the alerts to
    /// deliver now.
    public func evaluate(mgdL: Double, rate: Double?, at date: Date, state: inout AlertState) -> [AlertEvent] {
        let current = conditions(mgdL: mgdL, rate: rate)
        var events: [AlertEvent] = []
        for kind in AlertKind.allCases where kind != .signalLoss {
            guard current.contains(kind) else {
                // Cleared: forget the repeat timer so a recurrence alerts at once.
                state.lastFired[kind] = nil
                continue
            }
            if state.isSnoozed(kind, at: date) { continue }
            let isNew = !state.active.contains(kind)
            let due = state.lastFired[kind].map { date.timeIntervalSince($0) >= settings[kind].repeatInterval } ?? true
            if isNew || due {
                events.append(AlertEvent(kind: kind, mgdL: mgdL, rate: rate, date: date))
                state.lastFired[kind] = date
            }
        }
        state.active = current
        for (kind, until) in state.snoozedUntil where until <= date {
            state.snoozedUntil[kind] = nil
        }
        return events
    }

    /// Silences `kind` for its configured snooze duration.
    public func snooze(_ kind: AlertKind, at date: Date, state: inout AlertState) {
        state.snoozedUntil[kind] = date.addingTimeInterval(settings[kind].snoozeDuration)
    }
}

/// Something that can schedule and cancel one pending notification by
/// identifier (UNUserNotificationCenter in the app).
public protocol PendingNotificationScheduling: Sendable {
    func schedule(identifier: String, at date: Date, kind: AlertKind) async
    func cancel(identifier: String) async
}

/// The signal-loss alert works without the app running: every reading
/// replaces one pending notification set for `threshold` minutes later. If
/// readings stop — out of range, sensor failed, app suspended — iOS
/// delivers it on its own.
public struct SignalLossWatchdog: Sendable {
    public static let identifier = "signal-loss"

    public let scheduler: any PendingNotificationScheduling

    public init(scheduler: any PendingNotificationScheduling) {
        self.scheduler = scheduler
    }

    public static func fireDate(lastReading: Date, settings: AlertSettings) -> Date {
        lastReading.addingTimeInterval(settings.signalLoss.threshold * 60)
    }

    public func readingArrived(at date: Date, settings: AlertSettings) async {
        guard settings.signalLoss.isEnabled else {
            await scheduler.cancel(identifier: Self.identifier)
            return
        }
        await scheduler.schedule(
            identifier: Self.identifier, at: Self.fireDate(lastReading: date, settings: settings), kind: .signalLoss)
    }

    /// Stop watching, for example when the sensor is removed or expires.
    public func stop() async {
        await scheduler.cancel(identifier: Self.identifier)
    }
}
