// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit
import SwiftData

/// One stored glucose value. Unique per sensor minute: `sensorSerial` plus
/// `sensorAge` (the sensor's own minute counter), which is what the
/// pipeline dedupes on.
@Model
final class GlucoseReading {
    #Unique<GlucoseReading>([\.sensorSerial, \.sensorAge])
    #Index<GlucoseReading>([\.date])

    var sensorSerial: String
    var sensorAge: Int
    var date: Date
    var mgdL: Double
    var raw: Int
    var rawTemperature: Int
    /// "trend" (one-minute) or "history" (fifteen-minute).
    var kind: String

    init(sensorSerial: String, sample: GlucoseSample) {
        self.sensorSerial = sensorSerial
        sensorAge = sample.sensorAge
        date = sample.date
        mgdL = sample.mgdL
        raw = sample.raw
        rawTemperature = sample.rawTemperature
        kind = sample.kind.rawValue
    }
}

/// The paired sensor and everything needed to reconnect to it without
/// another NFC scan. This is the app's only store of the sensor UID, patch
/// info, calibration and unlock counter.
@Model
final class Sensor {
    #Unique<Sensor>([\.serial])

    var serial: String
    /// `SensorType` raw value.
    var type: String
    var uid: Data
    var patchInfo: Data
    /// BLE MAC returned when streaming was enabled, most significant first.
    var mac: Data?
    var unlockCode: Int
    /// Incremented and saved before every BLE unlock write.
    var unlockCount: Int
    var calibration: Data
    var startDate: Date
    var maxAge: Int
    var pairedAt: Date
    /// CoreBluetooth's identifier for the peripheral, once connected.
    var peripheralIdentifier: UUID?
    var isActive: Bool

    init(
        serial: String, type: SensorType, uid: [UInt8], patchInfo: [UInt8], mac: [UInt8]?, unlockCode: UInt32,
        calibration: CalibrationInfo, startDate: Date, maxAge: Int, pairedAt: Date
    ) {
        self.serial = serial
        self.type = type.rawValue
        self.uid = Data(uid)
        self.patchInfo = Data(patchInfo)
        self.mac = mac.map { Data($0) }
        self.unlockCode = Int(unlockCode)
        unlockCount = 0
        self.calibration = (try? JSONEncoder().encode(calibration)) ?? Data()
        self.startDate = startDate
        self.maxAge = maxAge
        self.pairedAt = pairedAt
        isActive = true
    }

    var sensorType: SensorType? { SensorType(rawValue: type) }
    var calibrationInfo: CalibrationInfo? { try? JSONDecoder().decode(CalibrationInfo.self, from: calibration) }
    var expiryDate: Date { startDate.addingTimeInterval(Double(maxAge) * 60) }

    /// A value snapshot for the device layer, which must not touch the
    /// model context.
    var pairing: SensorPairing? {
        guard let calibrationInfo, let type = sensorType, let info = try? PatchInfo([UInt8](patchInfo)) else {
            return nil
        }
        return SensorPairing(
            serial: serial, type: type, uid: [UInt8](uid), patchInfo: info, mac: mac.map { [UInt8]($0) },
            unlockCode: UInt32(truncatingIfNeeded: unlockCode), calibration: calibrationInfo, startDate: startDate,
            maxAge: maxAge, peripheralIdentifier: peripheralIdentifier)
    }
}

/// What the device layer needs to find, unlock and decode a sensor.
nonisolated struct SensorPairing: Sendable, Hashable {
    var serial: String
    var type: SensorType
    var uid: [UInt8]
    var patchInfo: PatchInfo
    var mac: [UInt8]?
    var unlockCode: UInt32
    var calibration: CalibrationInfo
    var startDate: Date
    var maxAge: Int
    var peripheralIdentifier: UUID?

    var expiryDate: Date { startDate.addingTimeInterval(Double(maxAge) * 60) }
    var matcher: PeripheralMatcher { PeripheralMatcher(serial: serial, uid: uid, mac: mac) }
}
