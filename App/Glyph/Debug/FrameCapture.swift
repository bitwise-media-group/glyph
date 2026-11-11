// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit

/// The debug capture log (Sensor ▸ Debug ▸ Capture raw frames): enough to
/// replay a real sensor offline and to compare its factory values with
/// finger-pricks. One line per event, each starting with an ISO 8601 date:
///
/// - `sensor uid=… serial=… type=… start=… calibration=i1,i2,i3,i4,i5,i6`,
///   before the first frame from a sensor in each session: the factory
///   parameters, which only NFC delivers and the frames don't carry.
/// - `uid=… frame=…`: an encrypted BLE frame.
/// - `blood serial=… date=… mgdL=… sensorMgdL=…`: a finger-prick the user
///   entered, with the sensor's factory value at that moment.
enum FrameCapture {
    static var url: URL { URL.documentsDirectory.appending(path: "glyph-frames.log") }

    static func sensor(_ pairing: SensorPairing, at date: Date) {
        let c = pairing.calibration
        append(
            "\(date.ISO8601Format()) sensor uid=\(pairing.uid.hexString) serial=\(pairing.serial) "
                + "type=\(pairing.type.rawValue) start=\(pairing.startDate.ISO8601Format()) "
                + "calibration=\(c.i1),\(c.i2),\(c.i3),\(c.i4),\(c.i5),\(c.i6)")
    }

    static func frame(_ encrypted: [UInt8], pairing: SensorPairing, arrival: Date) {
        append("\(arrival.ISO8601Format()) uid=\(pairing.uid.hexString) frame=\(encrypted.hexString)")
    }

    static func blood(_ reading: BloodReading) {
        append(
            "\(reading.enteredAt.ISO8601Format()) blood serial=\(reading.sensorSerial) "
                + "date=\(reading.date.ISO8601Format()) mgdL=\(reading.mgdL) sensorMgdL=\(reading.sensorMgdL)")
    }

    private static func append(_ line: String) {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
