// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Testing

@testable import LibreKit

struct Libre2CryptoTests {
    @Test func decryptsFRAM1() throws {
        let info = try PatchInfo(Fixtures.FRAM1.patchInfo)
        let fram = try Libre2Crypto.decryptFRAM(Fixtures.FRAM1.encrypted, uid: Fixtures.FRAM1.uid, patchInfo: info)
        #expect(fram == Fixtures.FRAM1.decrypted)
    }

    @Test func decryptsFRAM2() throws {
        let info = try PatchInfo(Fixtures.FRAM2.patchInfo)
        let fram = try Libre2Crypto.decryptFRAM(Fixtures.FRAM2.encrypted, uid: Fixtures.FRAM2.uid, patchInfo: info)
        #expect(fram == Fixtures.FRAM2.decrypted)
    }

    @Test func framDecryptRejectsBadInput() throws {
        let info = try PatchInfo(Fixtures.FRAM1.patchInfo)
        #expect(throws: Libre2Crypto.Error.invalidUID) {
            try Libre2Crypto.decryptFRAM(Fixtures.FRAM1.encrypted, uid: [0x01], patchInfo: info)
        }
        #expect(throws: Libre2Crypto.Error.invalidLength(expected: 344, actual: 8)) {
            try Libre2Crypto.decryptFRAM(Array(repeating: 0, count: 8), uid: Fixtures.FRAM1.uid, patchInfo: info)
        }
    }

    @Test func decryptsBLE() throws {
        let payload = try Libre2Crypto.decryptBLE(Fixtures.BLE.encrypted, uid: Fixtures.BLE.uid)
        #expect(payload == Fixtures.BLE.decrypted)
    }

    @Test func encryptBLEInvertsDecrypt() throws {
        let nonce = UInt16(Fixtures.BLE.encrypted[0]) | UInt16(Fixtures.BLE.encrypted[1]) << 8
        let encrypted = try Libre2Crypto.encryptBLE(Fixtures.BLE.decrypted, uid: Fixtures.BLE.uid, nonce: nonce)
        #expect(encrypted == Fixtures.BLE.encrypted)
        let other = try Libre2Crypto.encryptBLE(Fixtures.BLE.decrypted, uid: Fixtures.BLE.uid, nonce: 0x1234)
        #expect(try Libre2Crypto.decryptBLE(other, uid: Fixtures.BLE.uid) == Fixtures.BLE.decrypted)
    }

    @Test func bleDecryptDetectsCorruption() {
        var frame = Fixtures.BLE.encrypted
        frame[10] ^= 0x80
        #expect(throws: Libre2Crypto.Error.crcMismatch) {
            try Libre2Crypto.decryptBLE(frame, uid: Fixtures.BLE.uid)
        }
    }

    @Test func bleDecryptWithTheWrongUIDFails() {
        #expect(throws: Libre2Crypto.Error.crcMismatch) {
            try Libre2Crypto.decryptBLE(Fixtures.BLE.encrypted, uid: Fixtures.FRAM1.uid)
        }
    }

    @Test func bleDecryptRejectsShortFrames() {
        #expect(throws: Libre2Crypto.Error.invalidLength(expected: 46, actual: 44)) {
            try Libre2Crypto.decryptBLE(Array(Fixtures.BLE.encrypted.prefix(44)), uid: Fixtures.BLE.uid)
        }
    }

    @Test func enableStreamingParameters() throws {
        let one = Libre2Crypto.enableStreamingParameters(
            uid: Fixtures.FRAM1.uid, patchInfo: try PatchInfo(Fixtures.FRAM1.patchInfo), unlockCode: 42)
        #expect(one.hexString == "1E2A0000008327513A")
        let two = Libre2Crypto.enableStreamingParameters(
            uid: Fixtures.FRAM2.uid, patchInfo: try PatchInfo(Fixtures.FRAM2.patchInfo), unlockCode: 42)
        #expect(two.hexString == "1E2A000000AD38D2FA")
    }

    @Test(arguments: [
        (UInt16(1), "2B000000D348C4EF9B00C285"),
        (2, "2C000000319717BBF55A31D4"),
        (100, "8E00000052DF5222C11A294F"),
    ])
    func streamingUnlockPayloadFRAM1(count: UInt16, expected: String) throws {
        let payload = Libre2Crypto.streamingUnlockPayload(
            uid: Fixtures.FRAM1.uid, patchInfo: try PatchInfo(Fixtures.FRAM1.patchInfo),
            unlockCode: 42, unlockCount: count)
        #expect(payload.count == 12)
        #expect(payload.hexString == expected)
    }

    @Test(arguments: [
        (UInt16(1), "2B0000007FADC346DAA38EC6"),
        (2, "2C000000C4512E3A64AB1175"),
        (100, "8E000000272798CF5C5F0667"),
    ])
    func streamingUnlockPayloadFRAM2(count: UInt16, expected: String) throws {
        let payload = Libre2Crypto.streamingUnlockPayload(
            uid: Fixtures.FRAM2.uid, patchInfo: try PatchInfo(Fixtures.FRAM2.patchInfo),
            unlockCode: 42, unlockCount: count)
        #expect(payload.hexString == expected)
    }

    @Test func unlockPayloadIsDeterministicAndCountSensitive() throws {
        let info = try PatchInfo(Fixtures.FRAM1.patchInfo)
        let first = Libre2Crypto.streamingUnlockPayload(
            uid: Fixtures.FRAM1.uid, patchInfo: info, unlockCode: 42, unlockCount: 7)
        let again = Libre2Crypto.streamingUnlockPayload(
            uid: Fixtures.FRAM1.uid, patchInfo: info, unlockCode: 42, unlockCount: 7)
        let next = Libre2Crypto.streamingUnlockPayload(
            uid: Fixtures.FRAM1.uid, patchInfo: info, unlockCode: 42, unlockCount: 8)
        #expect(first == again)
        #expect(first != next)
        #expect(Array(first.prefix(4)) == [49, 0, 0, 0])
    }

    @Test func unlockCounterWrapsInsteadOfTrapping() throws {
        let payload = Libre2Crypto.streamingUnlockPayload(
            uid: Fixtures.FRAM1.uid, patchInfo: try PatchInfo(Fixtures.FRAM1.patchInfo),
            unlockCode: .max, unlockCount: 2)
        #expect(Array(payload.prefix(4)) == [1, 0, 0, 0])
    }
}
