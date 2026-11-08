// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Testing

@testable import LibreKit

struct SensorTypeTests {
    static func type(_ hex: String) throws -> SensorType {
        try SensorType(patchInfo: PatchInfo([UInt8](hex: hex)!))
    }

    static func rejection(_ hex: String) -> UnsupportedSensorError? {
        do {
            _ = try SensorType(patchInfo: PatchInfo([UInt8](hex: hex)!))
            return nil
        } catch {
            return error
        }
    }

    @Test(arguments: [
        ("9D0830017317", SensorType.libre2EU),
        ("C50930010000", .libre2EU),
        ("7F0E30010000", .libre2EU),  // generation nibble 0
        ("C60931010000", .libre2PlusEU),
        ("7F0E31010000", .libre2PlusEU),  // generation nibble 1
    ])
    func supported(patchInfo: String, expected: SensorType) throws {
        #expect(try Self.type(patchInfo) == expected)
    }

    @Test(arguments: [
        ("E50003000000", UnsupportedSensorError.libreUS14Day),
        ("E60003000000", .libreUS14Day),
        ("DF0000010000", .libre1),
        ("A20800010000", .libre1),
        ("70001001000F", .libreProH),
        ("760830020000", .libre2US),
        ("760830040000", .libre2CA),
        ("760870080000", .libreSense),
        ("2C0A3A020000", .libre2Gen2),
        ("2B0A39080000", .libre2Gen2),
        ("123456780000", .unknown(0x12)),
    ])
    func rejected(patchInfo: String, expected: UnsupportedSensorError) {
        #expect(Self.rejection(patchInfo) == expected)
    }

    @Test func longPatchInfoIsLibre3() {
        #expect(Self.rejection("A5000100010000C04E1E0D0101040C04303955374E36584A50A7E9") == .libre3)
    }

    @Test func shortPatchInfoIsMalformed() {
        #expect(throws: UnsupportedSensorError.malformedPatchInfo([0x9D, 0x08])) {
            try PatchInfo([0x9D, 0x08])
        }
    }

    @Test func rejectionMessagesNameTheSensor() {
        #expect(UnsupportedSensorError.libre2US.description.hasPrefix("The US Libre 2 isn't supported"))
        #expect(UnsupportedSensorError.unknown(0x0A).description.contains("type 0A"))
    }

    @Test func patchInfoFields() throws {
        let info = try PatchInfo([UInt8](hex: "9D0830017317")!)
        #expect(info.family == 3)
        #expect(info.generation == 0)
        #expect(info.region == .europe)
        #expect(info.cryptoWord == 0x1773)
    }

    @Test func wearTimes() {
        #expect(SensorType.libre2EU.defaultMaxAge == 14 * 1440 + 720)
        #expect(SensorType.libre2PlusEU.defaultMaxAge == 15 * 1440 + 720)
        #expect(SensorType.warmUpMinutes == 60)
    }
}

struct SensorSerialTests {
    @Test func documentedWorkedExample() {
        // From the derivation in LibreTools' SensorSerialNumber.swift: the UID
        // E0 07 A0 00 00 25 90 5E (most significant first) is "0M00009DHCR".
        let uid = [UInt8](hex: "5E90250000A007E0")!
        #expect(SensorSerial.make(uid: uid, family: 0) == "0M00009DHCR")
    }

    @Test func libre2SerialsStartWithTheFamilyDigit() {
        #expect(SensorSerial.make(uid: Fixtures.FRAM1.uid, family: 3) == "3MH001HM1LM")
        #expect(SensorSerial.make(uid: Fixtures.FRAM2.uid, family: 3) == "3MH001GJ0VW")
    }

    @Test func rejectsWrongLength() {
        #expect(SensorSerial.make(uid: [0x01, 0x02], family: 3) == nil)
    }
}

struct PeripheralMatcherTests {
    let matcher = PeripheralMatcher(
        serial: "3MH001HM1LM", uid: Fixtures.FRAM1.uid, mac: [0xE0, 0x07, 0xA4, 0x00, 0x00, 0xC2])

    @Test func matchesTheAbbottName() {
        #expect(matcher.matches(name: "ABBOTT3MH001HM1LM", manufacturerData: nil))
        #expect(matcher.matches(name: "abbott3mh001hm1lm", manufacturerData: nil))
        #expect(!matcher.matches(name: "ABBOTT3MH001GJ0VW", manufacturerData: nil))
    }

    @Test func matchesTheMACName() {
        #expect(matcher.matches(name: "E0:07:A4:00:00:C2", manufacturerData: nil))
        #expect(matcher.matches(name: "e007a40000c2", manufacturerData: nil))
    }

    @Test func fallsBackToManufacturerData() {
        let data: [UInt8] = [0x00, 0x00] + Array(Fixtures.FRAM1.uid[0..<6])
        #expect(matcher.matches(name: nil, manufacturerData: data))
        #expect(matcher.matches(name: "Something else", manufacturerData: data))
        #expect(!matcher.matches(name: nil, manufacturerData: [0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        #expect(!matcher.matches(name: nil, manufacturerData: nil))
    }
}
