// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT
//
// Expected values are the output of a reference implementation
// (creepymonster/GlucoseDirect, MIT) for the same raw and calibration input;
// see docs/factory-calibration.md.

import Testing

@testable import LibreKit

struct FactoryCalibrationTests {
    static let fram1 = try! FRAM(decrypted: Fixtures.FRAM1.decrypted)
    static let fram2 = try! FRAM(decrypted: Fixtures.FRAM2.decrypted)

    @Test func convertsFRAM1Trend() {
        let calibration = FactoryCalibration(info: Self.fram1.calibrationInfo)
        #expect(
            Self.fram1.trend.map { calibration.glucose(for: $0) } == [
                99, 99, 99, 100, 101, 102, 103, 104, 104, 104, 105, 105, 105, 106, 107, 109,
            ])
    }

    @Test func convertsFRAM2Trend() {
        let calibration = FactoryCalibration(info: Self.fram2.calibrationInfo)
        #expect(
            Self.fram2.trend.map { calibration.glucose(for: $0) } == [
                95, 94, 94, 93, 93, 95, 96, 95, 96, 97, 98, 97, 97, 97, 98, 98,
            ])
    }

    static let grid: [(raw: Int, temperature: Int, adjustment: Int, mgdL: Double)] = [
        (600, 6000, -100, 33),
        (600, 6000, 0, 33),
        (600, 6000, 100, 32),
        (600, 7000, -100, 41),
        (600, 7000, 0, 40),
        (600, 7000, 100, 39),
        (600, 8000, -100, 48),
        (600, 8000, 0, 48),
        (600, 8000, 100, 47),
        (1000, 6000, -100, 66),
        (1000, 6000, 0, 65),
        (1000, 6000, 100, 63),
        (1000, 7000, -100, 79),
        (1000, 7000, 0, 77),
        (1000, 7000, 100, 76),
        (1000, 8000, -100, 91),
        (1000, 8000, 0, 90),
        (1000, 8000, 100, 88),
        (1500, 6000, -100, 106),
        (1500, 6000, 0, 105),
        (1500, 6000, 100, 103),
        (1500, 7000, -100, 126),
        (1500, 7000, 0, 124),
        (1500, 7000, 100, 122),
        (1500, 8000, -100, 145),
        (1500, 8000, 0, 142),
        (1500, 8000, 100, 140),
        (2000, 6000, -100, 147),
        (2000, 6000, 0, 144),
        (2000, 6000, 100, 142),
        (2000, 7000, -100, 173),
        (2000, 7000, 0, 170),
        (2000, 7000, 100, 168),
        (2000, 8000, -100, 198),
        (2000, 8000, 0, 195),
        (2000, 8000, 100, 192),
        (2500, 6000, -100, 187),
        (2500, 6000, 0, 184),
        (2500, 6000, 100, 182),
        (2500, 7000, -100, 220),
        (2500, 7000, 0, 216),
        (2500, 7000, 100, 213),
        (2500, 8000, -100, 251),
        (2500, 8000, 0, 248),
        (2500, 8000, 100, 244),
    ]

    @Test func matchesTheReferenceAcrossRawTemperatureAndAdjustment() {
        let calibration = FactoryCalibration(info: Self.fram1.calibrationInfo)
        for row in Self.grid {
            let value = calibration.glucose(
                raw: row.raw, rawTemperature: row.temperature, temperatureAdjustment: row.adjustment)
            #expect(value == row.mgdL, "raw \(row.raw), temperature \(row.temperature), adjustment \(row.adjustment)")
        }
    }

    /// Codes either side of every band boundary in the sensitivity grid.
    static let sweep: [(i2: Int, mgdL: Double)] = [
        (1, 2339), (8, 2293), (9, 2316), (100, 2058), (512, 1225), (513, 1237), (600, 1112), (719, 971), (720, 981),
        (800, 888), (951, 728), (952, 735), (1000, 694), (1023, 670),
    ]

    @Test func matchesTheReferenceAcrossTheSensitivityGrid() {
        for row in Self.sweep {
            let calibration = FactoryCalibration(
                info: CalibrationInfo(i1: 1, i2: row.i2, i3: 0, i4: 1500, i5: 0, i6: 4000))
            #expect(
                calibration.glucose(raw: 1200, rawTemperature: 7000, temperatureAdjustment: 0) == row.mgdL,
                "i2 \(row.i2)")
        }
    }

    @Test func gridShape() {
        #expect(FactoryCalibration.bands.map { $0.rows * $0.width }.reduce(0, +) == 1023)
        let first = FactoryCalibration.sensitivity(code: 1)!
        #expect(first.offset == 0.75)
        #expect(first.slope == 0.0377442)
        let last = FactoryCalibration.sensitivity(code: 1023)!
        #expect(last.offset == 3.0)
        #expect(last.slope == 0.1283452)
        #expect(FactoryCalibration.sensitivity(code: 0) == nil)
        #expect(FactoryCalibration.sensitivity(code: 1024) == nil)
    }

    @Test func temperatureIsPlausibleForSkin() throws {
        let celsius = try #require(
            FactoryCalibration.temperature(rawTemperature: 6552, adjustment: -4, reference: 6948))
        #expect(celsius > 25 && celsius < 40)
    }

    @Test func noValueForDegenerateInput() {
        let calibration = FactoryCalibration(info: Self.fram1.calibrationInfo)
        #expect(
            calibration.glucose(
                for: RawReading(sensorAge: 100, raw: 0, rawTemperature: 0, temperatureAdjustment: 0, errorCode: 32))
                == nil)
        #expect(calibration.glucose(raw: 1000, rawTemperature: 0, temperatureAdjustment: 0) == nil)
        let flat = FactoryCalibration(info: CalibrationInfo(i1: 0, i2: 858, i3: 100, i4: 100, i5: 0, i6: 6948))
        #expect(flat.glucose(raw: 1000, rawTemperature: 6500, temperatureAdjustment: 0) == nil)
        let outOfGrid = FactoryCalibration(info: CalibrationInfo(i1: 0, i2: 0, i3: 14, i4: 6772, i5: 0, i6: 6948))
        #expect(outOfGrid.glucose(raw: 1000, rawTemperature: 6500, temperatureAdjustment: 0) == nil)
    }
}
