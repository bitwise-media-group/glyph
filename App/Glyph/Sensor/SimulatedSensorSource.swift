// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore
import LibreKit

/// A stand-in sensor for the simulator and SwiftUI previews.
///
/// It emits genuine encrypted frames once a minute for a sensor with the
/// public LibreTools example UID and calibration, so everything after the
/// radio — decryption, CRC, parsing, factory calibration, the pipeline — runs
/// exactly as it does on a device. Glucose follows a slow sine with noise;
/// the raw value for a target mg/dL is found by bisecting the converter.
final class SimulatedSensorSource: SensorSource {
    /// The LibreTools `Libre2.Example` sensor (MIT; see NOTICE).
    static let uid: [UInt8] = [0x9D, 0x81, 0xC2, 0x00, 0x00, 0xA4, 0x07, 0xE0]
    static let patchInfo: [UInt8] = [0x9D, 0x08, 0x30, 0x01, 0x73, 0x17]
    static let calibration = CalibrationInfo(i1: 0, i2: 858, i3: 14, i4: 6772, i5: 9360, i6: 6948)

    /// A pairing as an NFC scan would produce, started `age` ago.
    static func pairing(startedAgo age: TimeInterval = 3 * 86_400, now: Date = .now) -> SensorPairing {
        SensorPairing(
            serial: SensorSerial.make(uid: uid, family: 3) ?? "3SIMULATED",
            type: .libre2EU, uid: uid, patchInfo: try! PatchInfo(patchInfo), mac: nil, unlockCode: 42,
            calibration: calibration, startDate: now.addingTimeInterval(-age),
            maxAge: SensorType.libre2EU.defaultMaxAge,
            peripheralIdentifier: nil)
    }

    let events: AsyncStream<SensorEvent>
    private let continuation: AsyncStream<SensorEvent>.Continuation
    private let interval: Duration
    private let converter = FactoryCalibration(info: calibration)
    /// A cool skin reading (about 24 °C), so values up to about 370 mg/dL fit
    /// under the raw ceiling (`FrameSanity.maximumRaw`); at body temperature
    /// highs would saturate and trip the "values stopped changing" rule.
    private let rawTemperature = 9800
    /// A fixed story for UI tests and screenshots; `nil` for the free-running
    /// simulator.
    private let scenario: GlucoseScenario?
    /// When the scenario's story ends ("now" at start).
    private var storyEnd = Date.now
    private var task: Task<Void, Never>?
    private var generator = SystemRandomNumberGenerator()

    init(interval: Duration = .seconds(60), scenario: GlucoseScenario? = nil) {
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.interval = interval
        self.scenario = scenario
    }

    func start(_ pairing: SensorPairing) {
        task?.cancel()
        storyEnd = .now
        let lastReading = storyEnd.addingTimeInterval(-Double(scenario?.minutesSinceLastReading ?? 0) * 60)
        task = Task { [weak self] in
            guard let self else { return }
            continuation.yield(.link(.connecting))
            continuation.yield(.samples(history(for: pairing, days: 14, before: lastReading)))
            continuation.yield(.link(.connected))
            continuation.yield(.signal(rssi: -62))
            if let scenario, !scenario.isLive {
                // Signal lost: one last frame, already stale, then silence.
                if scenario.minutesSinceLastReading > 0 { emitFrame(for: pairing, at: lastReading) }
                continuation.yield(.link(.disconnected))
                return
            }
            while !Task.isCancelled {
                emitFrame(for: pairing, at: .now)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        continuation.yield(.link(.idle))
    }

    /// The scenario's curve, or for the free-running simulator a 3-hour
    /// swing around 130 mg/dL with a slower daily drift and a little noise.
    private func mgdL(at date: Date) -> Double {
        if let scenario { return scenario.mgdL(at: date, now: storyEnd) }
        let t = date.timeIntervalSinceReferenceDate
        let wave = 45 * sin(t / (3 * 3600) * 2 * .pi) + 25 * sin(t / 86_400 * 2 * .pi + 1)
        let jitter = Double.random(in: -3...3, using: &generator)
        return min(max(130 + wave + jitter, 45), 380)
    }

    private func raw(for target: Double) -> Int {
        var low = 1
        var high = FrameSanity.maximumRaw
        while low < high {
            let middle = (low + high) / 2
            let value = converter.glucose(raw: middle, rawTemperature: rawTemperature, temperatureAdjustment: 0) ?? 0
            if value < target { low = middle + 1 } else { high = middle }
        }
        return low
    }

    private func record(age: Int, start: Date) -> RawReading {
        let date = start.addingTimeInterval(Double(age) * 60)
        return RawReading(
            sensorAge: age, raw: raw(for: mgdL(at: date)), rawTemperature: rawTemperature, temperatureAdjustment: 0)
    }

    private func emitFrame(for pairing: SensorPairing, at arrival: Date) {
        let age = Int(arrival.timeIntervalSince(pairing.startDate) / 60)
        let trend = BLEFrame.trendOffsets.map { record(age: age - $0, start: pairing.startDate) }
        let newestHistory = (age - 2) / 15 * 15
        let history = (0..<3).map { record(age: newestHistory - 15 * $0, start: pairing.startDate) }
        do {
            let payload = BLEFrame.payload(age: age, trend: trend, history: history)
            let encrypted = try Libre2Crypto.encryptBLE(payload, uid: pairing.uid, nonce: .random(in: 0...UInt16.max))
            let frame = try BLEFrame(encrypted: encrypted, uid: pairing.uid)
            continuation.yield(.frame(frame, encrypted: encrypted, arrival: arrival))
        } catch {
            continuation.yield(.failure("Simulator frame failed: \(error)"))
        }
    }

    /// Past readings so the charts and statistics have something to show:
    /// every minute for the three hours before `end`, every five before that.
    private func history(for pairing: SensorPairing, days: Int, before end: Date) -> [GlucoseSample] {
        let endAge = Int(end.timeIntervalSince(pairing.startDate) / 60)
        let firstAge = max(SensorType.warmUpMinutes, endAge - days * 1440)
        let recent = Array(stride(from: endAge - 1, through: max(firstAge, endAge - 180), by: -1))
        let older = Array(stride(from: endAge - 185, through: firstAge, by: -5))
        return (recent + older).map { age in
            let date = pairing.startDate.addingTimeInterval(Double(age) * 60)
            return GlucoseSample(
                sensorAge: age, date: date, mgdL: mgdL(at: date).rounded(), raw: 0, rawTemperature: rawTemperature,
                kind: .trend)
        }
    }
}
