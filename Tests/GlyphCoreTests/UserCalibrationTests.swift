// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit
import Testing

@testable import GlyphCore

struct UserCalibrationTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func point(hours: Double, blood: Double, sensor: Double) -> CalibrationPoint {
        CalibrationPoint(date: start.addingTimeInterval(hours * 3600), bloodMgdL: blood, sensorMgdL: sensor)
    }

    @Test func noPointsMeansNoCorrection() {
        #expect(UserCalibration.fit([]) == nil)
    }

    @Test func onePointIsAnOffset() throws {
        let correction = try #require(UserCalibration.fit([point(hours: 0, blood: 110, sensor: 80)]))
        #expect(correction == LinearCorrection(slope: 1, offset: 30))
        #expect(correction.apply(80) == 110)
        #expect(correction.apply(200) == 230)
    }

    @Test func closePointsAverageTheirOffsets() throws {
        // Same time, so equal weights: offsets 30 and 20 average to 25.
        let correction = try #require(
            UserCalibration.fit([point(hours: 0, blood: 110, sensor: 80), point(hours: 0, blood: 120, sensor: 100)]))
        #expect(correction.slope == 1)
        #expect(abs(correction.offset - 25) < 1e-9)
    }

    @Test func spreadPointsFitALine() throws {
        // blood = 1.2 × sensor + 4
        let points = [
            point(hours: 0, blood: 100, sensor: 80), point(hours: 1, blood: 184, sensor: 150),
            point(hours: 2, blood: 136, sensor: 110),
        ]
        let correction = try #require(UserCalibration.fit(points))
        #expect(abs(correction.slope - 1.2) < 1e-9)
        #expect(abs(correction.offset - 4) < 1e-9)
    }

    @Test func slopeIsClamped() throws {
        let correction = try #require(
            UserCalibration.fit([point(hours: 0, blood: 60, sensor: 80), point(hours: 0, blood: 300, sensor: 140)]))
        #expect(correction.slope == UserCalibration.slopeRange.upperBound)
        // The clamped line still passes through the (weighted) mean point.
        #expect(abs(correction.apply(110) - 180) <= 1)
    }

    @Test func newerPointsWeighMore() throws {
        let correction = try #require(
            UserCalibration.fit([point(hours: 0, blood: 100, sensor: 100), point(hours: 48, blood: 130, sensor: 100)]))
        // Weights ½ and 1: offset (0 × ½ + 30 × 1) / 1½ = 20.
        #expect(abs(correction.offset - 20) < 1e-9)
    }

    @Test func pointsOutsideTheWindowAreDropped() throws {
        let correction = try #require(
            UserCalibration.fit([point(hours: 0, blood: 200, sensor: 100), point(hours: 120, blood: 110, sensor: 100)]))
        #expect(correction == LinearCorrection(slope: 1, offset: 10))
    }

    @Test func correctedValuesAreRoundedAndNeverNegative() {
        let correction = LinearCorrection(slope: 1.1, offset: -60)
        #expect(correction.apply(101) == 51)
        #expect(correction.apply(20) == 0)
    }

    @Test func correctingASampleKeepsEverythingButTheValue() {
        let sample = GlucoseSample(sensorAge: 900, date: start, mgdL: 80, raw: 1234, rawTemperature: 6400, kind: .trend)
        #expect(sample.corrected(by: nil) == sample)
        let corrected = sample.corrected(by: LinearCorrection(slope: 1, offset: 30))
        #expect(corrected.mgdL == 110)
        #expect(corrected.sensorAge == 900)
        #expect(corrected.raw == 1234)
    }

    @Test func sensorValueInterpolatesBetweenNeighbours() throws {
        let readings: [(date: Date, mgdL: Double)] = [
            (start, 100), (start.addingTimeInterval(60), 110), (start.addingTimeInterval(20 * 60), 200),
        ]
        let between = try #require(UserCalibration.sensorValue(at: start.addingTimeInterval(30), readings: readings))
        #expect(abs(between - 105) < 1e-9)
        #expect(UserCalibration.sensorValue(at: start.addingTimeInterval(4 * 60), readings: readings) == 110)
        #expect(UserCalibration.sensorValue(at: start.addingTimeInterval(10 * 60), readings: readings) == nil)
    }

    @Test func steadinessFollowsTheFlatArrow() {
        #expect(UserCalibration.isSteady(rate: nil))
        #expect(UserCalibration.isSteady(rate: -0.5))
        #expect(!UserCalibration.isSteady(rate: 1.5))
        #expect(!UserCalibration.isSteady(rate: -1))
    }

    @Test func rateUsesTheReadingsUpToThatTime() throws {
        // Rising 2 mg/dL a minute until the finger-prick, then flat.
        let readings = (0...30).map { minute -> (date: Date, mgdL: Double) in
            (start.addingTimeInterval(Double(minute) * 60), 100 + 2 * Double(min(minute, 15)))
        }
        let rate = try #require(UserCalibration.rate(at: start.addingTimeInterval(15 * 60), readings: readings))
        #expect(abs(rate - 2) < 0.1)
    }
}
