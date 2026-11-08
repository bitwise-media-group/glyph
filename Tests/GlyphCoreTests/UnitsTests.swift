// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Testing

@testable import GlyphCore

struct UnitsTests {
    @Test(arguments: [
        (GlucoseUnit.mmolL, 100.0, "5.5"), (.mmolL, 70, "3.9"), (.mmolL, 180, "10.0"), (.mgdL, 101.4, "101"),
        (.mgdL, 39, "LO"), (.mmolL, 501, "HI"), (.mgdL, 40, "40"), (.mgdL, 500, "500"),
    ])
    func formatsValues(unit: GlucoseUnit, mgdL: Double, expected: String) {
        #expect(unit.format(mgdL: mgdL) == expected)
    }

    @Test func includesTheUnitOnRequest() {
        #expect(GlucoseUnit.mmolL.format(mgdL: 100, withUnit: true) == "5.5 mmol/L")
        #expect(GlucoseUnit.mgdL.format(mgdL: 100, withUnit: true) == "100 mg/dL")
    }

    @Test(arguments: [
        (GlucoseUnit.mmolL, 5.0, "+0.3"), (.mmolL, -9.0, "\u{2212}0.5"), (.mmolL, 0.4, "0.0"), (.mgdL, -5, "\u{2212}5"),
        (.mgdL, 0, "0"),
    ])
    func formatsDeltas(unit: GlucoseUnit, delta: Double, expected: String) {
        #expect(unit.formatDelta(mgdL: delta) == expected)
    }

    @Test func roundTripsThroughMmol() {
        let unit = GlucoseUnit.mmolL
        #expect(abs(unit.mgdL(from: unit.value(fromMgdL: 123)) - 123) < 1e-9)
    }

    @Test(arguments: [
        (50.0, GlucoseLevel.urgentLow), (60, .low), (70, .inRange), (180, .inRange), (181, .high),
    ])
    func levels(mgdL: Double, level: GlucoseLevel) {
        #expect(GlucoseLevel(mgdL: mgdL, target: .standard) == level)
    }
}
