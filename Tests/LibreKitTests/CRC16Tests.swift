// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Testing

@testable import LibreKit

struct CRC16Tests {
    @Test func checkValue() {
        // CRC-16 (poly 0x1021, reflected input, seed 0xFFFF) of "123456789" is
        // 0x6F91 before the final bit reversal.
        #expect(CRC16.libre(Array("123456789".utf8)) == 0x89F6)
    }

    @Test func emptyInputIsTheReversedSeed() {
        #expect(CRC16.libre([UInt8]()) == 0xFFFF)
    }

    @Test(arguments: [Fixtures.FRAM1.decrypted, Fixtures.FRAM2.decrypted])
    func framSectionsCarryValidCRCs(fram: [UInt8]) {
        #expect(CRC16.isValid(fram, storedAt: 0, covering: 2..<24))
        #expect(CRC16.isValid(fram, storedAt: 24, covering: 26..<320))
        #expect(CRC16.isValid(fram, storedAt: 320, covering: 322..<344))
    }

    @Test func bleFrameCarriesValidCRC() {
        #expect(CRC16.isValid(Fixtures.BLE.decrypted, storedAt: 42, covering: 0..<42))
    }

    @Test func flippedBitFails() {
        var fram = Fixtures.FRAM1.decrypted
        fram[100] ^= 0x01
        #expect(!CRC16.isValid(fram, storedAt: 24, covering: 26..<320))
    }

    @Test func outOfRangeIsInvalidRatherThanCrashing() {
        #expect(!CRC16.isValid([0x00, 0x01], storedAt: 1, covering: 0..<2))
        #expect(!CRC16.isValid([0x00, 0x01, 0x02], storedAt: 0, covering: 2..<10))
    }
}
