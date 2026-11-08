// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT
//
// ISOLATED FILE — see NOTICE and docs/factory-calibration.md.
//
// Written from the plain-language specification in
// docs/factory-calibration.md, not from any existing implementation. The
// algorithm itself first appeared publicly in xdripswift (GPL-3.0); its
// licence status is unresolved, so it lives alone here behind the
// GlucoseConverter protocol. Obtain a legal opinion before the repository is
// published, and replace this file if advised.

import Foundation

/// The sensor's factory calibration: raw signal, thermistor and the FRAM's
/// `i2`/`i3`/`i4`/`i6` parameters to mg/dL.
public struct FactoryCalibration: GlucoseConverter, Hashable, Codable {
    public let info: CalibrationInfo

    public init(info: CalibrationInfo) {
        self.info = info
    }

    public func glucose(for reading: RawReading) -> Double? {
        guard reading.errorCode == nil, reading.raw > 0 else { return nil }
        return glucose(
            raw: reading.raw, rawTemperature: reading.rawTemperature,
            temperatureAdjustment: reading.temperatureAdjustment)
    }

    /// The four steps of the specification: temperature, normalised signal,
    /// temperature compensation, sensitivity.
    public func glucose(raw: Int, rawTemperature: Int, temperatureAdjustment: Int) -> Double? {
        guard
            let celsius = Self.temperature(
                rawTemperature: rawTemperature, adjustment: temperatureAdjustment, reference: info.i6)
        else { return nil }
        guard info.i4 != info.i3, let cell = Self.sensitivity(code: info.i2) else { return nil }

        let normalised = 65 * Double(raw - info.i3) / Double(info.i4 - info.i3)
        let compensated = normalised * pow(1.045, 32.5 - celsius)
        let mgdL = ((compensated - cell.offset) / cell.slope).rounded()
        return mgdL.isFinite ? mgdL : nil
    }

    // MARK: Step 1 — sensor temperature

    static let divider = 72_500.0  // 71.5 kΩ + 1 kΩ
    static let seriesResistance = 1_000.0
    static let steinhart = (a: 9.180023e-4, b: 1.964561e-4, c: 7.061775e-7, d: 5.283566e-8)

    /// Thermistor temperature in °C, or `nil` when the resistance is not
    /// positive.
    static func temperature(rawTemperature: Int, adjustment: Int, reference: Int) -> Double? {
        let denominator = Double(adjustment + reference)
        guard denominator != 0 else { return nil }
        let resistance = divider * Double(rawTemperature) / denominator - seriesResistance
        guard resistance > 0 else { return nil }
        let l = log(resistance)
        let inverseKelvin = steinhart.a + steinhart.b * l + steinhart.c * l * l + steinhart.d * l * l * l
        let celsius = 1 / inverseKelvin - 273.15
        return celsius.isFinite ? celsius : nil
    }

    // MARK: Step 4 — the sensitivity grid

    /// One band of rows in the grid: `rows` rows of `width` cells, offsets
    /// starting at `firstOffset` and stepping by 0.25.
    struct Band {
        let rows: Int
        let width: Int
        let firstOffset: Double
    }

    static let bands = [
        Band(rows: 64, width: 8, firstOffset: 0.75),
        Band(rows: 23, width: 9, firstOffset: 0.75),
        Band(rows: 29, width: 8, firstOffset: 1.0),
        Band(rows: 8, width: 9, firstOffset: 1.0),
    ]
    static let offsetStep = 0.25
    static let baseSlope = 0.0377442272
    static let slopeGrowth = 1.01

    /// The offset and slope for sensitivity code `code` (1–1023).
    static func sensitivity(code: Int) -> (offset: Double, slope: Double)? {
        guard code >= 1 else { return nil }
        var cell = code - 1
        var row = 0
        for band in bands {
            let size = band.rows * band.width
            if cell < size {
                let slope = (baseSlope * pow(slopeGrowth, Double(row + cell / band.width)) * 1e7).rounded() / 1e7
                return (band.firstOffset + offsetStep * Double(cell % band.width), slope)
            }
            cell -= size
            row += band.rows
        }
        return nil
    }
}
