// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore
import LibreKit
import Observation
import SwiftData
import os

/// The sensor's lifecycle, owned by the main actor:
///
/// `noSensor → scanning → connecting → warmingUp → streaming ⇄ signalLost`,
/// ending in `expired`, or `failed` when a scan goes wrong.
@Observable
final class SensorController: UnlockCounter {
    enum Phase: Equatable {
        case noSensor
        /// An NFC scan is in progress.
        case scanning
        /// Paired; waiting for the first frame.
        case connecting
        case warmingUp(minutesRemaining: Int)
        case streaming
        case signalLost(since: Date)
        case expired
        case failed(String)

        var label: String {
            switch self {
            case .noSensor: "No sensor"
            case .scanning: "Scanning"
            case .connecting: "Connecting"
            case .warmingUp(let minutes): "Warming up, \(minutes) min left"
            case .streaming: "Streaming"
            case .signalLost: "Signal lost"
            case .expired: "Sensor ended"
            case .failed: "Pairing failed"
            }
        }
    }

    /// No frame for this long while streaming means the signal is lost (the
    /// alert waits longer; see `AlertSettings.signalLoss`).
    static let signalLostAfter: TimeInterval = 5 * 60

    private(set) var phase: Phase = .noSensor
    private(set) var pairing: SensorPairing?
    private(set) var link: LinkState = .idle
    private(set) var rssi: Int?
    private(set) var lastFrameAt: Date?
    private(set) var framesReceived = 0
    private(set) var framesDropped = 0
    private(set) var isSimulated = false
    /// The latest user-facing problem, cleared on the next success.
    var lastError: String?

    /// Raw frame hex dumps, when capture is on (Settings ▸ Debug).
    static var captureURL: URL { URL.documentsDirectory.appending(path: "glyph-frames.log") }

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let pipeline: ReadingPipeline
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let scenario: GlucoseScenario?
    @ObservationIgnored private let reader = NFCSensorReader()
    @ObservationIgnored private var bluetooth: Libre2Peripheral?
    @ObservationIgnored private var simulator: SimulatedSensorSource?
    @ObservationIgnored private var listeners: [Task<Void, Never>] = []
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "sensor")

    init(context: ModelContext, pipeline: ReadingPipeline, settings: AppSettings, scenario: GlucoseScenario? = nil) {
        self.scenario = scenario
        self.context = context
        self.pipeline = pipeline
        self.settings = settings
    }

    /// Called once at launch, including background relaunches for Bluetooth
    /// state restoration: brings up the radio and reconnects to the paired
    /// sensor.
    func resume() {
        if let scenario {
            // UI tests and screenshots: no Bluetooth, just the scenario.
            startWatchdog()
            if let age = scenario.sensorAge { pairSimulated(startedAgo: age) }
            return
        }
        if !settings.useSimulatedSensor {
            // Created eagerly so CoreBluetooth can hand back a restored
            // peripheral even before a sensor is loaded.
            _ = bluetoothSource()
        }
        startWatchdog()
        if let sensor = activeSensor(), let pairing = sensor.pairing {
            begin(pairing, simulated: settings.useSimulatedSensor && sensor.mac == nil)
        } else if settings.useSimulatedSensor {
            pairSimulated()
        }
    }

    // MARK: Pairing

    /// Scans a sensor over NFC and starts streaming from it. In simulated
    /// mode it pairs the simulated sensor instead.
    func scan() async {
        if settings.useSimulatedSensor {
            pairSimulated()
            return
        }
        let previous = phase
        phase = .scanning
        lastError = nil
        do {
            let result = try await reader.scan()
            pair(with: result)
        } catch let error as NFCScanError where error == .cancelled {
            phase = previous
        } catch {
            lastError = error.localizedDescription
            phase = pairing == nil ? .failed(error.localizedDescription) : previous
        }
    }

    private func pair(with scan: NFCScanResult) {
        let startDate = SensorClock.startDate(age: scan.fram.age, arrival: scan.scanDate)
        let maxAge = scan.fram.maxLife ?? scan.type.defaultMaxAge
        let sensor = upsertSensor(serial: scan.serial) {
            Sensor(
                serial: scan.serial, type: scan.type, uid: scan.uid, patchInfo: scan.patchInfo.bytes, mac: scan.mac,
                unlockCode: scan.unlockCode, calibration: scan.fram.calibrationInfo, startDate: startDate,
                maxAge: maxAge, pairedAt: scan.scanDate)
        }
        sensor.patchInfo = Data(scan.patchInfo.bytes)
        sensor.mac = Data(scan.mac)
        sensor.unlockCode = Int(scan.unlockCode)
        sensor.unlockCount = 0  // a new unlock code starts a new count
        sensor.startDate = startDate
        sensor.maxAge = maxAge
        save()

        guard let pairing = sensor.pairing else { return }
        // Back-fill the last 15 minutes and up to 8 hours of history from the FRAM.
        let decoder = FrameDecoder(
            converter: FactoryCalibration(info: pairing.calibration), clock: SensorClock(startDate: startDate),
            maxAge: maxAge)
        let samples = decoder.samples(from: scan.fram, scanDate: scan.scanDate)
        Task { await pipeline.ingest(samples, current: nil, pairing: pairing) }
        begin(pairing, simulated: false)
    }

    private func pairSimulated(startedAgo age: TimeInterval = 10 * 86_400) {
        let pairing = SimulatedSensorSource.pairing(startedAgo: age)
        let sensor = upsertSensor(serial: pairing.serial) {
            Sensor(
                serial: pairing.serial, type: pairing.type, uid: pairing.uid, patchInfo: pairing.patchInfo.bytes,
                mac: nil, unlockCode: pairing.unlockCode, calibration: pairing.calibration,
                startDate: pairing.startDate, maxAge: pairing.maxAge, pairedAt: .now)
        }
        save()
        begin(sensor.pairing ?? pairing, simulated: true)
    }

    /// Stops streaming and forgets the sensor (its readings are kept).
    func removeSensor() {
        stopSources()
        if let sensor = activeSensor() {
            sensor.isActive = false
            save()
        }
        pairing = nil
        phase = .noSensor
        link = .idle
        rssi = nil
        Task { await pipeline.sensorEnded() }
    }

    private func begin(_ pairing: SensorPairing, simulated: Bool) {
        stopSources()
        self.pairing = pairing
        isSimulated = simulated
        if Date.now >= pairing.expiryDate {
            phase = .expired
            return
        }
        phase = .connecting
        let source: any SensorSource = simulated ? simulatedSource() : bluetoothSource()
        source.start(pairing)
    }

    private func stopSources() {
        bluetooth?.stop()
        simulator?.stop()
    }

    private func bluetoothSource() -> Libre2Peripheral {
        if let bluetooth { return bluetooth }
        let source = Libre2Peripheral(unlockCounter: self)
        bluetooth = source
        listen(to: source)
        return source
    }

    private func simulatedSource() -> SimulatedSensorSource {
        if let simulator { return simulator }
        let source = SimulatedSensorSource(scenario: scenario)
        simulator = source
        listen(to: source)
        return source
    }

    private func listen(to source: any SensorSource) {
        let stream = source.events
        listeners.append(
            Task { [weak self] in
                for await event in stream {
                    await self?.handle(event)
                }
            })
    }

    // MARK: Events

    private func handle(_ event: SensorEvent) async {
        switch event {
        case .link(let state):
            link = state
        case .signal(let value):
            rssi = value
        case .peripheralIdentified(let id):
            if let sensor = activeSensor(), sensor.peripheralIdentifier != id {
                sensor.peripheralIdentifier = id
                save()
                pairing?.peripheralIdentifier = id
            }
        case .failure(let message):
            framesDropped += 1
            log.error("\(message, privacy: .public)")
        case .samples(let samples):
            guard let pairing else { return }
            await pipeline.ingest(samples, current: nil, pairing: pairing, isSimulated: isSimulated)
        case .frame(let frame, let encrypted, let arrival):
            await handle(frame, encrypted: encrypted, arrival: arrival)
        }
    }

    private func handle(_ frame: BLEFrame, encrypted: [UInt8], arrival: Date) async {
        guard let pairing else { return }
        lastFrameAt = arrival
        framesReceived += 1
        if settings.captureRawFrames { capture(encrypted, pairing: pairing, arrival: arrival) }

        let decoder = FrameDecoder(
            converter: FactoryCalibration(info: pairing.calibration), clock: SensorClock(startDate: pairing.startDate),
            maxAge: pairing.maxAge)
        switch decoder.decode(frame, arrival: arrival) {
        case .warmingUp(let minutes):
            phase = .warmingUp(minutesRemaining: minutes)
        case .expired:
            phase = .expired
            stopSources()
            await pipeline.sensorEnded()
        case .rejected(let verdict):
            framesDropped += 1
            log.error("frame rejected: \(String(describing: verdict), privacy: .public)")
        case .readings(let current, let samples):
            phase = .streaming
            lastError = nil
            await pipeline.ingest(samples, current: current, pairing: pairing, isSimulated: isSimulated)
        }
        // A frame that was already stale on arrival marks the signal lost at once.
        checkSignal(now: .now)
    }

    /// Marks the signal lost after five minutes without a frame, and ends a
    /// sensor that has run past its wear time without saying so.
    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.checkSignal(now: .now)
            }
        }
    }

    private func checkSignal(now: Date) {
        if let pairing, now >= pairing.expiryDate, phase != .expired {
            phase = .expired
            stopSources()
            Task { await pipeline.sensorEnded() }
            return
        }
        switch phase {
        case .streaming, .warmingUp:
            if let lastFrameAt, now.timeIntervalSince(lastFrameAt) > Self.signalLostAfter {
                phase = .signalLost(since: lastFrameAt)
            }
        default:
            break
        }
    }

    // MARK: UnlockCounter

    func nextUnlockCount() -> UInt16 {
        guard let sensor = activeSensor() else { return 1 }
        sensor.unlockCount += 1
        save()  // before the write, or a crash could replay a used count
        return UInt16(truncatingIfNeeded: sensor.unlockCount)
    }

    // MARK: Store

    private func activeSensor() -> Sensor? {
        var descriptor = FetchDescriptor<Sensor>(
            predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.pairedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// The sensor with `serial`, made active, every other sensor inactive.
    private func upsertSensor(serial: String, make: () -> Sensor) -> Sensor {
        let all = (try? context.fetch(FetchDescriptor<Sensor>())) ?? []
        for other in all where other.serial != serial { other.isActive = false }
        if let existing = all.first(where: { $0.serial == serial }) {
            existing.isActive = true
            return existing
        }
        let sensor = make()
        context.insert(sensor)
        return sensor
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func capture(_ encrypted: [UInt8], pairing: SensorPairing, arrival: Date) {
        let line = "\(arrival.ISO8601Format()) uid=\(pairing.uid.hexString) frame=\(encrypted.hexString)\n"
        let url = Self.captureURL
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
