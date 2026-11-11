// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore
import LibreKit
import Observation
import SwiftData
import WidgetKit
import os

/// The value the UI shows as "now".
struct CurrentGlucose: Equatable {
    /// What to show: the factory value, corrected when calibrated.
    var mgdL: Double
    var factoryMgdL: Double
    var serial: String
    var date: Date
    var trend: TrendArrow
    var rate: Double?
    var deltaMgdL: Double?

    /// Whether the user's calibration changed the value shown.
    var isCalibrated: Bool { mgdL != factoryMgdL }
}

/// Why a finger-prick couldn't be used.
enum CalibrationError: LocalizedError, Equatable {
    case outOfRange
    case noSensorReading
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .outOfRange: "That value is outside what a finger-prick meter reads. Check the unit."
        case .noSensorReading: "There's no sensor reading within 5 minutes of that time."
        case .saveFailed: "The finger-prick couldn't be saved."
        }
    }
}

/// The single fan-out for new readings:
/// dedupe by (serial, sensor minute) → store → alerts → HealthKit →
/// Live Activity → widgets.
///
/// Samples arrive with the sensor's factory value. When the user has entered
/// finger-pricks for the sensor (and calibration is on) the pipeline applies
/// their correction before anything else sees the value, and stores the
/// factory value beside it. The correction applies to readings from then on;
/// stored readings keep the value they were shown with.
@Observable
final class ReadingPipeline {
    private(set) var current: CurrentGlucose?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let alerts: AlertNotifier
    @ObservationIgnored private let health: HealthKitWriter
    @ObservationIgnored private let liveActivity: LiveActivityController
    /// Off in UI tests, so scenario data never reaches the user's widgets
    /// through the shared App Group.
    @ObservationIgnored private let updatesWidgets: Bool
    @ObservationIgnored private var widgetReloads = Throttle(interval: 5 * 60)
    /// Fitted corrections by sensor serial (`nil`: no finger-pricks).
    @ObservationIgnored private var fits: [String: LinearCorrection?] = [:]
    @ObservationIgnored private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "pipeline")

    init(
        context: ModelContext, settings: AppSettings, alerts: AlertNotifier, health: HealthKitWriter,
        liveActivity: LiveActivityController, updatesWidgets: Bool = true
    ) {
        self.updatesWidgets = updatesWidgets
        self.context = context
        self.settings = settings
        self.alerts = alerts
        self.health = health
        self.liveActivity = liveActivity
        current = latestStored()
    }

    /// Stores what's new in `samples`. When `current` is set (a live frame's
    /// 0-minute record), it is also evaluated for alerts and pushed to the
    /// Live Activity and widgets. Simulated readings never go to Health.
    func ingest(
        _ samples: [GlucoseSample], current live: GlucoseSample?, pairing: SensorPairing, isSimulated: Bool = false
    ) async {
        let correction = correction(for: pairing.serial)
        let fresh = store(samples, serial: pairing.serial, correction: correction)

        if settings.healthKitEnabled, !isSimulated, !fresh.isEmpty {
            await health.write(fresh, serial: pairing.serial)
        }

        guard let factoryLive = live else {
            if !fresh.isEmpty { refreshSurfaces(pairing: pairing, force: true) }
            return
        }
        let live = factoryLive.corrected(by: correction)

        let recent = readings(since: live.date.addingTimeInterval(-20 * 60))
        let points = recent.map { (date: $0.date, mgdL: $0.mgdL) }
        let rate = Trend.rate(of: points)
        let delta = ReadingMerge.delta(current: (live.date, live.mgdL), history: points.filter { $0.date < live.date })
        current = CurrentGlucose(
            mgdL: live.mgdL, factoryMgdL: factoryLive.mgdL, serial: pairing.serial, date: live.date,
            trend: TrendArrow(rate: rate), rate: rate, deltaMgdL: delta)

        await alerts.evaluate(mgdL: live.mgdL, rate: rate, at: live.date, settings: settings.alerts)
        await alerts.rescheduleSignalLoss(lastReading: live.date, settings: settings.alerts)
        refreshSurfaces(pairing: pairing, force: false)
    }

    /// The sensor stopped (expired or removed): end the Live Activity and
    /// stop the signal-loss watchdog.
    func sensorEnded() async {
        await liveActivity.end()
        await alerts.stopSignalLoss()
        writeSnapshot(expiry: nil)
        reloadWidgets()
    }

    // MARK: Store

    /// Stores the new samples, corrected, and returns them corrected.
    private func store(_ samples: [GlucoseSample], serial: String, correction: LinearCorrection?)
        -> [GlucoseSample]
    {
        guard let lowest = samples.map(\.sensorAge).min(), let highest = samples.map(\.sensorAge).max() else {
            return []
        }
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate {
                $0.sensorSerial == serial && $0.sensorAge >= lowest && $0.sensorAge <= highest
            })
        let existing = Set(((try? context.fetch(descriptor)) ?? []).map(\.sensorAge))
        let fresh = ReadingMerge.newSamples(samples, existingAges: existing)
        guard !fresh.isEmpty else { return [] }
        for sample in fresh {
            context.insert(GlucoseReading(sensorSerial: serial, sample: sample, correction: correction))
        }
        do {
            try context.save()
        } catch {
            log.error("save failed: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            return []
        }
        return fresh.map { $0.corrected(by: correction) }
    }

    private func readings(since date: Date) -> [GlucoseReading] {
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate { $0.date >= date }, sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func latestStored() -> CurrentGlucose? {
        var descriptor = FetchDescriptor<GlucoseReading>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let latest = try? context.fetch(descriptor).first else { return nil }
        return CurrentGlucose(
            mgdL: latest.mgdL, factoryMgdL: latest.uncalibratedMgdL, serial: latest.sensorSerial, date: latest.date,
            trend: .unknown, rate: nil, deltaMgdL: nil)
    }

    // MARK: Calibration

    /// The correction applied to `serial`'s new readings: `nil` when
    /// calibration is off or the sensor has no finger-pricks.
    func correction(for serial: String) -> LinearCorrection? {
        settings.calibrationEnabled ? fittedCorrection(for: serial) : nil
    }

    /// The correction `serial`'s finger-pricks give, whether or not
    /// calibration is on.
    func fittedCorrection(for serial: String) -> LinearCorrection? {
        if let fit = fits[serial] { return fit }
        let descriptor = FetchDescriptor<BloodReading>(predicate: #Predicate { $0.sensorSerial == serial })
        let fit = UserCalibration.fit(((try? context.fetch(descriptor)) ?? []).map(\.point))
        fits[serial] = fit
        return fit
    }

    /// The sensor's factory value at `date`, and how fast it was changing,
    /// for pairing with a finger-prick.
    func sensorValue(at date: Date, serial: String) -> (mgdL: Double, rate: Double?)? {
        let from = date.addingTimeInterval(-UserCalibration.pairingTolerance - 20 * 60)
        let to = date.addingTimeInterval(UserCalibration.pairingTolerance)
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate { $0.sensorSerial == serial && $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\.date)])
        let points = ((try? context.fetch(descriptor)) ?? []).map { (date: $0.date, mgdL: $0.uncalibratedMgdL) }
        guard let value = UserCalibration.sensorValue(at: date, readings: points) else { return nil }
        return (value, UserCalibration.rate(at: date, readings: points))
    }

    /// Records a finger-prick of `mgdL` taken at `date` against `serial`.
    func addBloodReading(mgdL: Double, at date: Date, serial: String) throws(CalibrationError) {
        guard UserCalibration.bloodRange.contains(mgdL) else { throw .outOfRange }
        guard let sensor = sensorValue(at: date, serial: serial) else { throw .noSensorReading }
        let reading = BloodReading(sensorSerial: serial, date: date, mgdL: mgdL, sensorMgdL: sensor.mgdL)
        context.insert(reading)
        guard save() else { throw .saveFailed }
        if settings.captureRawFrames { FrameCapture.blood(reading) }
        calibrationChanged()
    }

    func deleteBloodReading(_ reading: BloodReading) {
        context.delete(reading)
        _ = save()
        calibrationChanged()
    }

    /// Deletes every finger-prick for `serial`.
    func resetCalibration(serial: String) {
        try? context.delete(model: BloodReading.self, where: #Predicate { $0.sensorSerial == serial })
        _ = save()
        calibrationChanged()
    }

    /// Refits, and re-shows the current value with the new correction (the
    /// next reading carries it to the widgets and Live Activity).
    func calibrationChanged() {
        fits = [:]
        guard var current else { return }
        current.mgdL = correction(for: current.serial)?.apply(current.factoryMgdL) ?? current.factoryMgdL
        self.current = current
    }

    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            log.error("save failed: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            return false
        }
    }

    // MARK: Surfaces

    private func refreshSurfaces(pairing: SensorPairing, force: Bool) {
        let now = Date.now
        let recent = readings(since: now.addingTimeInterval(-WidgetSnapshot.window))
            .map { WidgetSnapshot.Point(date: $0.date, mgdL: $0.mgdL) }
        writeSnapshot(recent: recent, expiry: pairing.expiryDate)

        if let current, settings.liveActivityEnabled {
            let state = GlucoseActivityAttributes.ContentState(
                mgdL: current.mgdL, date: current.date, trend: current.trend, deltaMgdL: current.deltaMgdL,
                unit: settings.unit, target: settings.target, recent: Self.downsample(recent, last: 3600, step: 300))
            Task { await liveActivity.update(state, serial: pairing.serial, expiry: pairing.expiryDate) }
        }

        // Widgets have a daily reload budget; the Live Activity is the
        // real-time surface.
        if force || widgetReloads.shouldFire(at: now) {
            reloadWidgets()
        }
    }

    private func reloadWidgets() {
        guard updatesWidgets else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func writeSnapshot(recent: [WidgetSnapshot.Point] = [], expiry: Date?) {
        guard updatesWidgets else { return }
        let snapshot = WidgetSnapshot(
            latest: current.map { .init(date: $0.date, mgdL: $0.mgdL) },
            recent: WidgetSnapshot.trimmed(recent, now: .now),
            trend: current?.trend ?? .unknown, deltaMgdL: current?.deltaMgdL, unit: settings.unit,
            target: settings.target, sensorExpiry: expiry, updatedAt: .now)
        do {
            try SnapshotStore.write(snapshot)
        } catch {
            log.error("snapshot write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// One point per `step` seconds over the last `last` seconds.
    static func downsample(_ points: [WidgetSnapshot.Point], last: TimeInterval, step: TimeInterval)
        -> [WidgetSnapshot.Point]
    {
        guard let newest = points.last?.date else { return [] }
        var result: [WidgetSnapshot.Point] = []
        var next = newest.addingTimeInterval(-last)
        for point in points where point.date >= next {
            result.append(point)
            next = point.date.addingTimeInterval(step)
        }
        return result
    }
}
