// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import GlyphCore
import Observation

/// User preferences, kept in the App Group's defaults so the widgets see the
/// same unit and target range. (Sensor secrets live in SwiftData, not here.)
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var unit: GlucoseUnit { didSet { defaults.set(unit.rawValue, forKey: Key.unit) } }
    var target: TargetRange { didSet { store(target, Key.target) } }
    var alerts: AlertSettings { didSet { store(alerts, Key.alerts) } }
    var healthKitEnabled: Bool { didSet { defaults.set(healthKitEnabled, forKey: Key.healthKit) } }
    var liveActivityEnabled: Bool { didSet { defaults.set(liveActivityEnabled, forKey: Key.liveActivity) } }
    /// Whether the user's finger-prick values correct the sensor's readings.
    /// It only has an effect once a sensor has some; off, the factory value
    /// is used and the finger-pricks are kept.
    var calibrationEnabled: Bool { didSet { defaults.set(calibrationEnabled, forKey: Key.calibration) } }
    /// Debug: append every raw BLE frame to a hex dump for test fixtures.
    var captureRawFrames: Bool { didSet { defaults.set(captureRawFrames, forKey: Key.captureRawFrames) } }
    /// Debug: replay a synthetic sensor instead of Bluetooth. Always on in
    /// the simulator.
    var useSimulatedSensor: Bool { didSet { defaults.set(useSimulatedSensor, forKey: Key.simulated) } }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        unit = defaults.string(forKey: Key.unit).flatMap(GlucoseUnit.init(rawValue:)) ?? .mmolL
        target = Self.load(TargetRange.self, Key.target, from: defaults) ?? .standard
        alerts = Self.load(AlertSettings.self, Key.alerts, from: defaults) ?? .defaults
        healthKitEnabled = defaults.bool(forKey: Key.healthKit)
        liveActivityEnabled = defaults.object(forKey: Key.liveActivity) as? Bool ?? true
        calibrationEnabled = defaults.object(forKey: Key.calibration) as? Bool ?? true
        captureRawFrames = defaults.bool(forKey: Key.captureRawFrames)
        #if targetEnvironment(simulator)
            useSimulatedSensor = true
        #else
            useSimulatedSensor = defaults.bool(forKey: Key.simulated)
        #endif
    }

    private enum Key {
        static let unit = "unit"
        static let target = "targetRange"
        static let alerts = "alertSettings"
        static let healthKit = "healthKitEnabled"
        static let liveActivity = "liveActivityEnabled"
        static let calibration = "calibrationEnabled"
        static let captureRawFrames = "captureRawFrames"
        static let simulated = "useSimulatedSensor"
    }

    private func store(_ value: some Encodable, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
