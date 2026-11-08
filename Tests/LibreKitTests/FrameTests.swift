// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@testable import LibreKit

struct FRAMTests {
    @Test func parsesFRAM1() throws {
        let fram = try FRAM(decrypted: Fixtures.FRAM1.decrypted)
        #expect(fram.state == .active)
        #expect(fram.age == 10_320)
        #expect(fram.maxLife == 20_719)
        #expect(fram.region == .europe)
        #expect(fram.calibrationInfo == CalibrationInfo(i1: 0, i2: 858, i3: 14, i4: 6772, i5: 9360, i6: 6948))
    }

    @Test func parsesFRAM2() throws {
        let fram = try FRAM(decrypted: Fixtures.FRAM2.decrypted)
        #expect(fram.state == .active)
        #expect(fram.age == 3170)
        #expect(fram.maxLife == 20_759)
        #expect(fram.calibrationInfo == CalibrationInfo(i1: 0, i2: 898, i3: 24, i4: 6819, i5: 8904, i6: 6192))
    }

    @Test func decryptsAndValidatesInOneStep() throws {
        let fram = try FRAM(
            encrypted: Fixtures.FRAM1.encrypted, uid: Fixtures.FRAM1.uid,
            patchInfo: try PatchInfo(Fixtures.FRAM1.patchInfo))
        #expect(fram.bytes == Fixtures.FRAM1.decrypted)
    }

    @Test func trendRingIsNewestFirst() throws {
        let fram = try FRAM(decrypted: Fixtures.FRAM1.decrypted)
        #expect(fram.trend.count == 16)
        #expect(fram.trend.map(\.sensorAge) == (0..<16).map { 10_320 - $0 })
        #expect(
            fram.trend.map(\.raw) == [
                1314, 1317, 1322, 1326, 1336, 1345, 1352, 1357, 1356, 1368, 1374, 1377, 1385, 1397, 1403, 1416,
            ])
        #expect(fram.trend[0].rawTemperature == 6552)
        #expect(fram.trend[0].temperatureAdjustment == -4)
        #expect(fram.trend[6].temperatureAdjustment == 0)
    }

    @Test func historyRingLagsTheAge() throws {
        let fram = try FRAM(decrypted: Fixtures.FRAM1.decrypted)
        #expect(fram.history.count == 32)
        // age 10320: (10320 - 3) % 15 + 3 = 15, so the newest history record is for age 10305.
        #expect(fram.history.first?.sensorAge == 10_305)
        #expect(fram.history.last?.sensorAge == 10_305 - 31 * 15)
    }

    @Test(arguments: [(5, FRAM.Error.headerCRC), (100, .bodyCRC), (330, .footerCRC)])
    func rejectsCorruptSections(offset: Int, expected: FRAM.Error) {
        var bytes = Fixtures.FRAM1.decrypted
        bytes[offset] ^= 0xFF
        #expect(throws: expected) { try FRAM(decrypted: bytes) }
    }

    @Test func rejectsWrongLength() {
        #expect(throws: FRAM.Error.invalidLength(343)) {
            try FRAM(decrypted: Array(Fixtures.FRAM1.decrypted.dropLast()))
        }
    }

    @Test func stateByte() {
        #expect(SensorState(byte: 1) == .notActivated)
        #expect(SensorState(byte: 6) == .failure)
        #expect(SensorState(byte: 0x42) == .unknown)
    }
}

struct BLEFrameTests {
    @Test func parsesTheFixture() throws {
        let frame = try BLEFrame(encrypted: Fixtures.BLE.encrypted, uid: Fixtures.BLE.uid)
        #expect(frame.age == 11_509)
        #expect(frame.trend.map(\.sensorAge) == [11_509, 11_507, 11_505, 11_503, 11_502, 11_497, 11_494])
        #expect(frame.trend.map(\.raw) == [2542, 2534, 2513, 2497, 2470, 2461, 2452])
        #expect(frame.trend.map(\.rawTemperature) == [6336, 6328, 6316, 6344, 6352, 6316, 6316])
        #expect(frame.trend.map(\.temperatureAdjustment) == [8, 12, 12, 8, 12, 12, 12])
        #expect(frame.trend.allSatisfy { $0.isValid })
    }

    @Test func historyRecordsSitOnTheFifteenMinuteGrid() throws {
        let frame = try BLEFrame(decrypted: Fixtures.BLE.decrypted)
        // (11509 - 2) / 15 * 15 = 11505
        #expect(frame.history.map(\.sensorAge) == [11_505, 11_490, 11_475])
        #expect(frame.history[0].raw == 2514)
        #expect(frame.history[0].isValid)
        // The two older history slots are error records: raw 0, code in the temperature bits.
        #expect(frame.history[1].isValid == false)
        #expect(frame.history[1].errorCode == 32)
        #expect(frame.history[2].errorCode == 32)
    }

    @Test func recordsAreNewestFirst() throws {
        let frame = try BLEFrame(decrypted: Fixtures.BLE.decrypted)
        let ages = frame.records.map(\.sensorAge)
        #expect(ages == ages.sorted(by: >))
        #expect(ages.count == 10)
    }

    @Test func payloadEncodingRoundTrips() throws {
        let frame = try BLEFrame(decrypted: Fixtures.BLE.decrypted)
        #expect(BLEFrame.payload(age: frame.age, trend: frame.trend, history: frame.history) == Fixtures.BLE.decrypted)
        let negative = RawReading(sensorAge: 0, raw: 1234, rawTemperature: 6400, temperatureAdjustment: -12)
        let flat = RawReading(sensorAge: 0, raw: 1000, rawTemperature: 6400, temperatureAdjustment: 0)
        let built = try BLEFrame(
            decrypted: BLEFrame.payload(
                age: 500, trend: [negative] + Array(repeating: flat, count: 6), history: [flat, flat, flat]))
        #expect(built.trend[0].raw == 1234)
        #expect(built.trend[0].temperatureAdjustment == -12)
        #expect(built.trend[0].rawTemperature == 6400)
    }

    @Test func rejectsBadCRCAndLength() {
        var bytes = Fixtures.BLE.decrypted
        bytes[3] ^= 0x01
        #expect(throws: BLEFrame.Error.crcMismatch) { try BLEFrame(decrypted: bytes) }
        #expect(throws: BLEFrame.Error.invalidLength(43)) {
            try BLEFrame(decrypted: Array(Fixtures.BLE.decrypted.prefix(43)))
        }
    }
}

struct BLEFrameAssemblerTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func assemblesThreeNotifications() {
        var assembler = BLEFrameAssembler()
        let frame = Fixtures.BLE.encrypted
        #expect(assembler.append(Array(frame[0..<20]), at: start) == nil)
        #expect(assembler.append(Array(frame[20..<38]), at: start + 0.1) == nil)
        #expect(assembler.append(Array(frame[38..<46]), at: start + 0.2) == frame)
    }

    @Test func discardsAStalePartialFrame() {
        var assembler = BLEFrameAssembler(timeout: 3)
        let frame = Fixtures.BLE.encrypted
        _ = assembler.append(Array(frame[0..<20]), at: start)
        // The rest of that frame never came; a new one starts 60 s later.
        #expect(assembler.append(Array(frame[0..<20]), at: start + 60) == nil)
        #expect(assembler.append(Array(frame[20..<38]), at: start + 60.1) == nil)
        #expect(assembler.append(Array(frame[38..<46]), at: start + 60.2) == frame)
    }

    @Test func emitsAtMostOneFrameAndResets() {
        var assembler = BLEFrameAssembler()
        let oversized = Fixtures.BLE.encrypted + [0xAA, 0xBB]
        #expect(assembler.append(oversized, at: start) == Fixtures.BLE.encrypted)
        #expect(assembler.append([0x01], at: start + 1) == nil)
    }
}
