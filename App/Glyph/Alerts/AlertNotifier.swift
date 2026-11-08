// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore
import UserNotifications
import os

/// Delivers what `AlertEngine` decides, through UNUserNotificationCenter.
///
/// Alerts are time-sensitive (they break through Focus; the capability is
/// in the entitlements). Critical alerts need a separate entitlement that
/// Apple grants on request: once it is in the entitlements, set
/// ``requestsCriticalAlerts`` and urgent alerts use the critical sound when
/// the user allows it.
final class AlertNotifier: NSObject {
    /// Flip once Apple grants `com.apple.developer.usernotifications.critical-alerts`.
    static let requestsCriticalAlerts = false

    static let category = "glucose-alert"
    static let snoozeAction = "snooze"

    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "alerts")
    private var engine = AlertEngine(settings: .defaults)
    private var state: AlertState {
        didSet { defaults.set(try? JSONEncoder().encode(state), forKey: "alertState") }
    }
    private var unitProvider: () -> GlucoseUnit
    /// Off in UI tests: no permission prompt, no alerts, nothing scheduled.
    private let isEnabled: Bool

    init(isEnabled: Bool = true, defaults: UserDefaults = AppGroup.defaults, unit: @escaping () -> GlucoseUnit) {
        self.isEnabled = isEnabled
        self.defaults = defaults
        unitProvider = unit
        state =
            defaults.data(forKey: "alertState").flatMap { try? JSONDecoder().decode(AlertState.self, from: $0) }
            ?? AlertState()
        super.init()
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Snooze", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [snooze], intentIdentifiers: [])
        ])
        center.delegate = self
    }

    func requestAuthorization() async {
        guard isEnabled else { return }
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if Self.requestsCriticalAlerts { options.insert(.criticalAlert) }
        do {
            _ = try await center.requestAuthorization(options: options)
        } catch {
            log.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func evaluate(mgdL: Double, rate: Double?, at date: Date, settings: AlertSettings) async {
        guard isEnabled else { return }
        engine.settings = settings
        var next = state
        let events = engine.evaluate(mgdL: mgdL, rate: rate, at: date, state: &next)
        state = next
        for event in events {
            await deliver(event)
        }
    }

    func snooze(_ kind: AlertKind, at date: Date = .now) {
        var next = state
        engine.snooze(kind, at: date, state: &next)
        state = next
    }

    private func content(for kind: AlertKind, mgdL: Double?, rate: Double?) async -> UNMutableNotificationContent {
        let unit = unitProvider()
        let content = UNMutableNotificationContent()
        content.title = kind.title
        if let mgdL {
            var body = unit.format(mgdL: mgdL, withUnit: true)
            if let rate {
                body += ", \(unit.formatDelta(mgdL: rate)) \(unit.symbol)/min"
            }
            content.body = body
        } else {
            content.body = "Glyph hasn't received a reading from your sensor. Keep your phone nearby."
        }
        content.categoryIdentifier = Self.category
        content.userInfo = ["kind": kind.rawValue]
        content.threadIdentifier = "glucose"
        var critical = false
        if kind.isUrgent, Self.requestsCriticalAlerts {
            critical = await center.notificationSettings().criticalAlertSetting == .enabled
        }
        content.interruptionLevel = critical ? .critical : .timeSensitive
        content.sound = critical ? .defaultCritical : .default
        return content
    }

    private func deliver(_ event: AlertEvent) async {
        let content = await content(for: event.kind, mgdL: event.mgdL, rate: event.rate)
        let request = UNNotificationRequest(identifier: event.kind.rawValue, content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
            log.error("alert delivery failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Signal loss

    func rescheduleSignalLoss(lastReading: Date, settings: AlertSettings) async {
        guard isEnabled else { return }
        await SignalLossWatchdog(scheduler: self).readingArrived(at: lastReading, settings: settings)
    }

    func stopSignalLoss() async {
        await SignalLossWatchdog(scheduler: self).stop()
    }
}

extension AlertNotifier: PendingNotificationScheduling {
    nonisolated func schedule(identifier: String, at date: Date, kind: AlertKind) async {
        await schedulePending(identifier: identifier, at: date, kind: kind)
    }

    nonisolated func cancel(identifier: String) async {
        await cancelPending(identifier: identifier)
    }

    /// Adding a request with an existing identifier replaces it, which is
    /// what makes the signal-loss alert slide forward with every reading.
    private func schedulePending(identifier: String, at date: Date, kind: AlertKind) async {
        let content = await content(for: kind, mgdL: nil, rate: nil)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            log.error(
                "could not schedule \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func cancelPending(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

extension AlertNotifier: @preconcurrency UNUserNotificationCenterDelegate {
    /// Show alerts as banners even with Glyph open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == Self.snoozeAction,
            let raw = response.notification.request.content.userInfo["kind"] as? String,
            let kind = AlertKind(rawValue: raw)
        else { return }
        snooze(kind)
    }
}
