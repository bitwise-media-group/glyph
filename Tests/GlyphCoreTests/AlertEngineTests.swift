// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@testable import GlyphCore

struct AlertEngineTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var engine = AlertEngine(settings: .defaults)

    func minutes(_ value: Double) -> Date { t0.addingTimeInterval(value * 60) }

    @Test func inRangeIsQuiet() {
        var state = AlertState()
        #expect(engine.evaluate(mgdL: 110, rate: 0.2, at: t0, state: &state).isEmpty)
        #expect(state.active.isEmpty)
    }

    @Test func lowFiresOnceThenRepeats() {
        var state = AlertState()
        #expect(engine.evaluate(mgdL: 65, rate: nil, at: t0, state: &state).map(\.kind) == [.low])
        // Still low a minute later: no repeat until the 15-minute interval.
        #expect(engine.evaluate(mgdL: 64, rate: nil, at: minutes(1), state: &state).isEmpty)
        #expect(engine.evaluate(mgdL: 64, rate: nil, at: minutes(14), state: &state).isEmpty)
        #expect(engine.evaluate(mgdL: 63, rate: nil, at: minutes(15), state: &state).map(\.kind) == [.low])
    }

    @Test func urgentLowSuppressesLow() {
        var state = AlertState()
        let events = engine.evaluate(mgdL: 50, rate: -1, at: t0, state: &state)
        #expect(events.map(\.kind) == [.urgentLow])
        #expect(state.active == [.urgentLow])
    }

    @Test func droppingFromLowToUrgentLowAlertsAgain() {
        var state = AlertState()
        _ = engine.evaluate(mgdL: 65, rate: nil, at: t0, state: &state)
        #expect(engine.evaluate(mgdL: 52, rate: nil, at: minutes(2), state: &state).map(\.kind) == [.urgentLow])
    }

    @Test func recoveringResetsSoTheNextLowAlertsImmediately() {
        var state = AlertState()
        _ = engine.evaluate(mgdL: 65, rate: nil, at: t0, state: &state)
        _ = engine.evaluate(mgdL: 80, rate: nil, at: minutes(3), state: &state)
        #expect(engine.evaluate(mgdL: 68, rate: nil, at: minutes(5), state: &state).map(\.kind) == [.low])
    }

    @Test func snoozeSilencesUntilItEnds() {
        var state = AlertState()
        _ = engine.evaluate(mgdL: 260, rate: nil, at: t0, state: &state)
        engine.snooze(.high, at: minutes(1), state: &state)
        #expect(state.isSnoozed(.high, at: minutes(30)))
        // Repeat interval (60 min) passes while snoozed (until minute 61): silent.
        #expect(engine.evaluate(mgdL: 270, rate: nil, at: minutes(60), state: &state).isEmpty)
        // Snooze over and the high persists: alert again.
        #expect(engine.evaluate(mgdL: 270, rate: nil, at: minutes(61), state: &state).map(\.kind) == [.high])
        #expect(state.snoozedUntil[.high] == nil)
    }

    @Test func snoozingLowDoesNotSilenceUrgentLow() {
        var state = AlertState()
        _ = engine.evaluate(mgdL: 65, rate: nil, at: t0, state: &state)
        engine.snooze(.low, at: t0, state: &state)
        #expect(engine.evaluate(mgdL: 50, rate: nil, at: minutes(5), state: &state).map(\.kind) == [.urgentLow])
    }

    @Test func rateAlertsWhenEnabled() {
        var settings = AlertSettings.defaults
        settings.fallingFast.isEnabled = true
        settings.risingFast.isEnabled = true
        let engine = AlertEngine(settings: settings)
        var state = AlertState()
        #expect(engine.evaluate(mgdL: 150, rate: -2.5, at: t0, state: &state).map(\.kind) == [.fallingFast])
        var rising = AlertState()
        #expect(engine.evaluate(mgdL: 150, rate: 2.0, at: t0, state: &rising).map(\.kind) == [.risingFast])
    }

    @Test func rateAlertsAreRedundantWithLevelAlerts() {
        var settings = AlertSettings.defaults
        settings.fallingFast.isEnabled = true
        settings.risingFast.isEnabled = true
        let engine = AlertEngine(settings: settings)
        #expect(engine.conditions(mgdL: 65, rate: -3) == [.low])
        #expect(engine.conditions(mgdL: 300, rate: 3) == [.high])
    }

    @Test func disabledRulesNeverFire() {
        var settings = AlertSettings.defaults
        settings.low.isEnabled = false
        settings.urgentLow.isEnabled = false
        #expect(AlertEngine(settings: settings).conditions(mgdL: 40, rate: nil).isEmpty)
    }

    @Test func stateRoundTripsThroughCodable() throws {
        var state = AlertState()
        _ = engine.evaluate(mgdL: 65, rate: nil, at: t0, state: &state)
        engine.snooze(.low, at: t0, state: &state)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(AlertState.self, from: data) == state)
    }
}

actor FakeScheduler: PendingNotificationScheduling {
    private(set) var pending: [String: (Date, AlertKind)] = [:]
    private(set) var scheduleCount = 0

    func schedule(identifier: String, at date: Date, kind: AlertKind) {
        pending[identifier] = (date, kind)
        scheduleCount += 1
    }

    func cancel(identifier: String) {
        pending[identifier] = nil
    }

    func pendingDate(_ identifier: String) -> Date? { pending[identifier]?.0 }
}

struct SignalLossWatchdogTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func everyReadingPushesTheAlertBack() async {
        let scheduler = FakeScheduler()
        let watchdog = SignalLossWatchdog(scheduler: scheduler)
        await watchdog.readingArrived(at: t0, settings: .defaults)
        #expect(await scheduler.pendingDate(SignalLossWatchdog.identifier) == t0.addingTimeInterval(20 * 60))
        await watchdog.readingArrived(at: t0.addingTimeInterval(60), settings: .defaults)
        #expect(await scheduler.pendingDate(SignalLossWatchdog.identifier) == t0.addingTimeInterval(21 * 60))
        #expect(await scheduler.pending.count == 1)
        #expect(await scheduler.scheduleCount == 2)
    }

    @Test func disablingCancels() async {
        let scheduler = FakeScheduler()
        let watchdog = SignalLossWatchdog(scheduler: scheduler)
        await watchdog.readingArrived(at: t0, settings: .defaults)
        var settings = AlertSettings.defaults
        settings.signalLoss.isEnabled = false
        await watchdog.readingArrived(at: t0.addingTimeInterval(60), settings: settings)
        #expect(await scheduler.pending.isEmpty)
    }

    @Test func stopCancels() async {
        let scheduler = FakeScheduler()
        let watchdog = SignalLossWatchdog(scheduler: scheduler)
        await watchdog.readingArrived(at: t0, settings: .defaults)
        await watchdog.stop()
        #expect(await scheduler.pending.isEmpty)
    }

    @Test func thresholdIsConfigurable() {
        var settings = AlertSettings.defaults
        settings.signalLoss.threshold = 30
        #expect(SignalLossWatchdog.fireDate(lastReading: t0, settings: settings) == t0.addingTimeInterval(1800))
    }
}
