// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@testable import LibreKit

/// A converter that reports the raw value, so the tests can follow records
/// through the decoder.
struct IdentityConverter: GlucoseConverter {
    func glucose(for reading: RawReading) -> Double? { Double(reading.raw) }
}

/// Builds a valid decrypted frame with chosen raw values and age.
func makeFrame(age: Int, trend: [Int], history: [Int] = [1000, 1000, 1000]) -> [UInt8] {
    precondition(trend.count == 7 && history.count == 3)
    var bytes = [UInt8](repeating: 0, count: 44)
    for (index, raw) in (trend + history).enumerated() {
        // raw in bits 0–13, temperature field 1600 (6400 / 4) in bits 14–25
        let word = UInt32(raw) | UInt32(1600) << 14
        for byte in 0..<4 { bytes[index * 4 + byte] = UInt8(truncatingIfNeeded: word >> (8 * byte)) }
    }
    bytes[40] = UInt8(truncatingIfNeeded: age)
    bytes[41] = UInt8(truncatingIfNeeded: age >> 8)
    let crc = CRC16.libre(bytes[0..<42])
    bytes[42] = UInt8(truncatingIfNeeded: crc)
    bytes[43] = UInt8(truncatingIfNeeded: crc >> 8)
    return bytes
}

struct FrameSanityTests {
    @Test func plainFrameIsOK() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 500, trend: [1000, 1001, 1002, 1003, 1004, 1005, 1006]))
        #expect(FrameSanity.check(frame) == .ok)
    }

    @Test func rawAboveThreeThousandIsImplausible() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 500, trend: [3001, 1001, 1002, 1003, 1004, 1005, 1006]))
        #expect(FrameSanity.check(frame) == .implausibleRaw(3001))
    }

    @Test func fiveRepeatedValuesMeanStuck() throws {
        let stuck = try BLEFrame(decrypted: makeFrame(age: 500, trend: [1200, 1200, 1200, 1200, 1200, 1005, 1006]))
        #expect(FrameSanity.check(stuck) == .stuck(1200))
        let four = try BLEFrame(decrypted: makeFrame(age: 500, trend: [1200, 1200, 1200, 1200, 1004, 1005, 1006]))
        #expect(FrameSanity.check(four) == .ok)
    }

    @Test func realFrameIsOK() throws {
        #expect(FrameSanity.check(try BLEFrame(decrypted: Fixtures.BLE.decrypted)) == .ok)
    }
}

struct SensorClockTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func usesTheSensorClockWhenItAgrees() {
        let clock = SensorClock(startDate: start)
        // The frame (age 600) arrives 50 s later than start + age predicts.
        let arrival = start.addingTimeInterval(600 * 60 + 50)
        #expect(clock.agrees(frameAge: 600, arrival: arrival))
        #expect(clock.date(sensorAge: 588, frameAge: 600, arrival: arrival) == start.addingTimeInterval(588 * 60))
    }

    @Test func fallsBackToArrivalWhenTheyDisagree() {
        let clock = SensorClock(startDate: start)
        let arrival = start.addingTimeInterval(600 * 60 + 180)
        #expect(!clock.agrees(frameAge: 600, arrival: arrival))
        #expect(clock.date(sensorAge: 588, frameAge: 600, arrival: arrival) == arrival.addingTimeInterval(-12 * 60))
    }

    @Test func withoutAStartDateUsesArrival() {
        let clock = SensorClock(startDate: nil)
        let arrival = start
        #expect(clock.date(sensorAge: 595, frameAge: 600, arrival: arrival) == arrival.addingTimeInterval(-300))
    }

    @Test func impliedStartDate() {
        #expect(SensorClock.startDate(age: 90, arrival: start) == start.addingTimeInterval(-5400))
    }
}

struct FrameDecoderTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func decoder(maxAge: Int = 20_880) -> FrameDecoder {
        FrameDecoder(converter: IdentityConverter(), clock: SensorClock(startDate: start), maxAge: maxAge)
    }

    @Test func decodesReadingsNewestFirst() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 600, trend: [1000, 1010, 1020, 1030, 1040, 1050, 1060]))
        let arrival = start.addingTimeInterval(600 * 60 + 20)
        guard case .readings(let current, let samples) = decoder().decode(frame, arrival: arrival) else {
            Issue.record("expected readings")
            return
        }
        #expect(current?.mgdL == 1000)
        #expect(current?.date == start.addingTimeInterval(600 * 60))
        #expect(samples.map(\.sensorAge) == [600, 598, 596, 594, 593, 588, 585, 585, 570, 555])
        #expect(samples.filter { $0.kind == .history }.count == 3)
    }

    @Test func warmUpStoresNothing() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 45, trend: [1000, 1010, 1020, 1030, 1040, 1050, 1060]))
        #expect(decoder().decode(frame, arrival: start) == .warmingUp(minutesRemaining: 15))
    }

    @Test func dropsRecordsFromInsideTheWarmUp() throws {
        // At age 70, the 12- and 15-minute-old records fall inside the first hour.
        let frame = try BLEFrame(decrypted: makeFrame(age: 70, trend: [1000, 1010, 1020, 1030, 1040, 1050, 1060]))
        guard case .readings(_, let samples) = decoder().decode(frame, arrival: start.addingTimeInterval(4200))
        else {
            Issue.record("expected readings")
            return
        }
        #expect(samples.allSatisfy { $0.sensorAge >= 60 })
        #expect(samples.map(\.sensorAge) == [70, 68, 66, 64, 63, 60])
    }

    @Test func expiresAtMaxAge() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 20_880, trend: [1000, 1010, 1020, 1030, 1040, 1050, 1060]))
        #expect(decoder().decode(frame, arrival: start) == .expired)
    }

    @Test func stuckValuesExpire() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 900, trend: [1200, 1200, 1200, 1200, 1200, 1200, 1200]))
        #expect(decoder().decode(frame, arrival: start) == .expired)
    }

    @Test func implausibleFramesAreRejected() throws {
        let frame = try BLEFrame(decrypted: makeFrame(age: 900, trend: [3500, 1010, 1020, 1030, 1040, 1050, 1060]))
        #expect(decoder().decode(frame, arrival: start) == .rejected(.implausibleRaw(3500)))
    }

    @Test func fixtureDecodesWithFactoryCalibration() throws {
        // The BLE fixture comes from a different sensor than FRAM1, so the
        // values only need to be plausible, not exact.
        let calibration = FactoryCalibration(info: try FRAM(decrypted: Fixtures.FRAM1.decrypted).calibrationInfo)
        let decoder = FrameDecoder(converter: calibration, clock: SensorClock(startDate: nil), maxAge: 20_880)
        let frame = try BLEFrame(decrypted: Fixtures.BLE.decrypted)
        guard case .readings(let current, let samples) = decoder.decode(frame, arrival: start) else {
            Issue.record("expected readings")
            return
        }
        let value = try #require(current?.mgdL)
        #expect(value > 40 && value < 400)
        #expect(samples.count == 8)  // seven trend records + one valid history record
    }

    @Test func framBackFill() throws {
        let fram = try FRAM(decrypted: Fixtures.FRAM1.decrypted)
        let calibration = FactoryCalibration(info: fram.calibrationInfo)
        let decoder = FrameDecoder(converter: calibration, clock: SensorClock(startDate: nil), maxAge: 20_880)
        let samples = decoder.samples(from: fram, scanDate: start)
        #expect(samples.first?.sensorAge == 10_320)
        #expect(samples.first?.date == start)
        #expect(samples.first?.mgdL == 99)
        #expect(samples.contains { $0.kind == .history })
    }
}

struct TrendTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func series(slope: Double, minutes: [Int] = [0, 2, 4, 6, 7, 12, 15]) -> [(date: Date, mgdL: Double)] {
        minutes.map { (now.addingTimeInterval(Double(-$0) * 60), 120 - slope * Double($0)) }
    }

    @Test func linearSeriesRecoversItsSlope() throws {
        let rate = try #require(Trend.rate(of: series(slope: 2.5)))
        #expect(abs(rate - 2.5) < 1e-9)
    }

    @Test func ignoresPointsOutsideTheWindow() throws {
        var points = series(slope: 1)
        points.append((now.addingTimeInterval(-40 * 60), 500))
        let rate = try #require(Trend.rate(of: points))
        #expect(abs(rate - 1) < 1e-9)
    }

    @Test func needsEnoughPointsAndSpan() {
        #expect(Trend.rate(of: series(slope: 1, minutes: [0, 2])) == nil)
        #expect(Trend.rate(of: series(slope: 1, minutes: [0, 1, 2])) == nil)
        #expect(Trend.rate(of: []) == nil)
    }

    @Test(arguments: [
        (3.5, TrendArrow.risingQuickly), (2.5, .rising), (1.5, .risingSlightly), (0.4, .flat), (-0.99, .flat),
        (-1.5, .fallingSlightly), (-2.5, .falling), (-3.0, .fallingQuickly),
    ])
    func arrowBuckets(rate: Double, arrow: TrendArrow) {
        #expect(TrendArrow(rate: rate) == arrow)
    }

    @Test func unknownWithoutARate() {
        #expect(TrendArrow(rate: nil) == .unknown)
        #expect(TrendArrow(rate: .nan) == .unknown)
    }
}
