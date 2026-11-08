// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// One measurement record as the sensor stores it, before calibration.
///
/// FRAM records are 6 bytes and BLE records 4, but both carry the same
/// fields: a 14-bit raw glucose signal, a 12-bit thermistor reading
/// (stored divided by 4) and a signed temperature adjustment (also / 4).
/// When the sensor couldn't measure, the raw value is 0 and the temperature
/// bits carry an error code instead.
public struct RawReading: Sendable, Hashable, Codable {
    /// Minutes since the sensor started that this record describes.
    public let sensorAge: Int
    public let raw: Int
    public let rawTemperature: Int
    public let temperatureAdjustment: Int
    /// The sensor's error code when it couldn't produce a value.
    public let errorCode: Int?

    public init(sensorAge: Int, raw: Int, rawTemperature: Int, temperatureAdjustment: Int, errorCode: Int? = nil) {
        self.sensorAge = sensorAge
        self.raw = raw
        self.rawTemperature = rawTemperature
        self.temperatureAdjustment = temperatureAdjustment
        self.errorCode = errorCode
    }

    public var isValid: Bool { errorCode == nil && raw > 0 && sensorAge >= 0 }

    /// Decodes a 4-byte BLE record at `offset`: raw in bits 0–13, temperature
    /// in 14–25, the adjustment magnitude in 26–30 and its sign in bit 31.
    static func ble(_ bytes: [UInt8], at offset: Int, sensorAge: Int) -> RawReading {
        let raw = Bytes.bits(bytes, byte: offset, bit: 0, count: 14)
        let temperature = Bytes.bits(bytes, byte: offset, bit: 14, count: 12) << 2
        var adjustment = Bytes.bits(bytes, byte: offset, bit: 26, count: 5) << 2
        if Bytes.bits(bytes, byte: offset, bit: 31, count: 1) == 1 { adjustment = -adjustment }
        return RawReading(
            sensorAge: sensorAge,
            raw: raw,
            rawTemperature: raw == 0 ? 0 : temperature,
            temperatureAdjustment: adjustment,
            errorCode: raw == 0 ? temperature >> 2 : nil)
    }

    /// Encodes this record into the 4-byte BLE layout at `offset` (the
    /// inverse of ``ble(_:at:sensorAge:)``), for the simulated sensor.
    func writeBLE(into bytes: inout [UInt8], at offset: Int) {
        let temperatureField = raw == 0 ? (errorCode ?? 0) : rawTemperature >> 2
        Bytes.setBits(&bytes, byte: offset, bit: 0, count: 14, to: raw)
        Bytes.setBits(&bytes, byte: offset, bit: 14, count: 12, to: temperatureField)
        Bytes.setBits(&bytes, byte: offset, bit: 26, count: 5, to: abs(temperatureAdjustment) >> 2)
        Bytes.setBits(&bytes, byte: offset, bit: 31, count: 1, to: temperatureAdjustment < 0 ? 1 : 0)
    }

    /// Decodes a 6-byte FRAM record at `offset`: raw in bits 0–13, quality
    /// flags in 14–25 (not used), temperature in 26–37, the adjustment
    /// magnitude in 38–46 and its sign in bit 47.
    static func fram(_ bytes: [UInt8], at offset: Int, sensorAge: Int) -> RawReading {
        let raw = Bytes.bits(bytes, byte: offset, bit: 0, count: 14)
        let temperature = Bytes.bits(bytes, byte: offset, bit: 26, count: 12) << 2
        var adjustment = Bytes.bits(bytes, byte: offset, bit: 38, count: 9) << 2
        if Bytes.bits(bytes, byte: offset, bit: 47, count: 1) == 1 { adjustment = -adjustment }
        return RawReading(
            sensorAge: sensorAge,
            raw: raw,
            rawTemperature: raw == 0 ? 0 : temperature,
            temperatureAdjustment: adjustment,
            errorCode: raw == 0 ? temperature >> 2 : nil)
    }
}
