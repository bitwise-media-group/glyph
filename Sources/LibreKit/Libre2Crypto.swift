// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT
//
// Ported from MIT-licensed code (see NOTICE):
//   - ivalkou/LibreTools, Sources/LibreTools/Sensor/Libre2.swift
//     (Copyright 2020 Ivan Valkou): the block cipher, FRAM and BLE decryption
//     and the command signature.
//   - creepymonster/GlucoseDirect, App/Modules/SensorConnector/SensorUtility.swift
//     (Copyright 2023 Reimar Metzen) and gui-dos/DiaBLE, DiaBLE/Libre2.swift
//     (Copyright 2026 Guido Soranzio): the enable-streaming parameters and the
//     BLE streaming-unlock payload.

/// The Libre 2 scrambling scheme: FRAM and BLE decryption plus the two
/// payloads that enable and unlock BLE streaming.
///
/// Every operation is keyed by the sensor UID (8 bytes, least significant
/// first, as ``SensorSerial`` expects) and built on one 64-bit block function
/// over four 16-bit words.
public enum Libre2Crypto {
    static let key: [UInt16] = [0xA0C5, 0x6860, 0x0000, 0x14C6]
    /// The `y` argument of the activation signature, also mixed into the
    /// BLE key and the unlock payload.
    static let activationSecret: UInt16 = 0x1B6A
    static let activateSubcommand: UInt8 = 0x1B
    public static let enableStreamingSubcommand: UInt8 = 0x1E

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidUID
        case invalidLength(expected: Int, actual: Int)
        case crcMismatch
    }

    // MARK: FRAM

    /// Decrypts the 43 × 8-byte FRAM blocks read over NFC.
    ///
    /// Each block is XORed with the block function's output for
    /// `x` = block number and `y` = the patch-info word XOR `0x44`.
    public static func decryptFRAM(_ encrypted: [UInt8], uid: [UInt8], patchInfo: PatchInfo) throws(Error) -> [UInt8] {
        guard uid.count == 8 else { throw .invalidUID }
        guard encrypted.count == FRAM.byteCount else {
            throw .invalidLength(expected: FRAM.byteCount, actual: encrypted.count)
        }
        let y = patchInfo.cryptoWord ^ 0x44
        var output = [UInt8]()
        output.reserveCapacity(encrypted.count)
        for block in 0..<FRAM.byteCount / 8 {
            let keystream = bytes(of: scramble(seed(uid: uid, x: UInt16(block), y: y)))
            for index in 0..<8 {
                output.append(encrypted[block * 8 + index] ^ keystream[index])
            }
        }
        return output
    }

    // MARK: BLE

    /// Decrypts a 46-byte BLE frame into its 44-byte payload and verifies the
    /// payload's trailing CRC.
    ///
    /// The first two bytes are a per-frame nonce; the remaining 44 are XORed
    /// with a keystream of eight chained block-function outputs.
    public static func decryptBLE(_ encrypted: [UInt8], uid: [UInt8]) throws(Error) -> [UInt8] {
        guard uid.count == 8 else { throw .invalidUID }
        guard encrypted.count == BLEFrame.encryptedByteCount else {
            throw .invalidLength(expected: BLEFrame.encryptedByteCount, actual: encrypted.count)
        }
        let keystream = bleKeystream(uid: uid, nonce: Bytes.le16(encrypted, 0))
        let payload = encrypted.dropFirst(2).enumerated().map { $1 ^ keystream[$0] }
        guard CRC16.isValid(payload, storedAt: 42, covering: 0..<42) else { throw .crcMismatch }
        return payload
    }

    /// The inverse of ``decryptBLE(_:uid:)``, for the simulated sensor and
    /// tests: prefixes `nonce` and XORs the 44-byte payload with the same
    /// keystream.
    public static func encryptBLE(_ payload: [UInt8], uid: [UInt8], nonce: UInt16) throws(Error) -> [UInt8] {
        guard uid.count == 8 else { throw .invalidUID }
        guard payload.count == BLEFrame.decryptedByteCount else {
            throw .invalidLength(expected: BLEFrame.decryptedByteCount, actual: payload.count)
        }
        let keystream = bleKeystream(uid: uid, nonce: nonce)
        return Bytes.le16Bytes(nonce) + payload.enumerated().map { $1 ^ keystream[$0] }
    }

    /// 64 keystream bytes: eight chained block outputs, seeded from the
    /// activation signature and the frame's nonce.
    static func bleKeystream(uid: [UInt8], nonce: UInt16) -> [UInt8] {
        let signature = activationSignature(uid: uid)
        let x = (Bytes.le16(signature, 0) ^ Bytes.le16(signature, 2)) | 0x63
        let y = nonce ^ 0x63
        var keystream = [UInt8]()
        var block = scramble(seed(uid: uid, x: x, y: y))
        for _ in 0..<8 {
            keystream += bytes(of: block)
            block = scramble(block)
        }
        return keystream
    }

    // MARK: Streaming

    /// The parameters for NFC command `0xA1` that enable BLE streaming:
    /// sub-command `0x1E`, `unlockCode` (little-endian), then a 4-byte
    /// signature. The sensor answers with its BLE MAC address (6 bytes,
    /// least significant first).
    ///
    /// `unlockCode` is any 32-bit value; the same value must be passed to
    /// ``streamingUnlockPayload(uid:patchInfo:unlockCode:unlockCount:)``.
    public static func enableStreamingParameters(uid: [UInt8], patchInfo: PatchInfo, unlockCode: UInt32) -> [UInt8] {
        let code = Bytes.le32Bytes(unlockCode)
        let y = patchInfo.cryptoWord ^ UInt16(truncatingIfNeeded: unlockCode)
        return [enableStreamingSubcommand] + code
            + signature(uid: uid, x: UInt16(enableStreamingSubcommand), y: y)
    }

    /// The 12 bytes written to characteristic F001 straight after connecting,
    /// without which the sensor drops the link.
    ///
    /// `unlockCount` must increase on every connection (persist it before
    /// writing). The first four bytes are `unlockCode + unlockCount`
    /// little-endian; the rest is a block-function MAC over that counter and
    /// the activation and enable-streaming signatures.
    public static func streamingUnlockPayload(
        uid: [UInt8], patchInfo: PatchInfo, unlockCode: UInt32, unlockCount: UInt16
    ) -> [UInt8] {
        let counter = Bytes.le32Bytes(unlockCode &+ UInt32(unlockCount))
        let activation = activationSignature(uid: uid)
        let enable = signature(
            uid: uid, x: UInt16(enableStreamingSubcommand),
            y: UInt16(truncatingIfNeeded: unlockCode) ^ patchInfo.cryptoWord)

        let first = scramble(
            seed(
                uid: uid,
                words: (
                    Bytes.le16(enable, 0) ^ Bytes.le16(counter, 2),
                    Bytes.le16(activation, 0),
                    Bytes.le16(enable, 2) ^ Bytes.le16(counter, 0),
                    Bytes.le16(activation, 2)
                )))
        let firstBytes = bytes(of: first)

        let second = scramble(
            seed(
                uid: uid,
                words: (
                    CRC16.libre([0xC1, 0xC4, 0xC3, 0xC0, 0xD4, 0xE1, 0xE7, 0xBA] + firstBytes[0..<2]),
                    CRC16.libre(firstBytes[2..<8]),
                    CRC16.libre(activation + enable[0..<2]),
                    CRC16.libre(enable[2..<4] + counter)
                )))
        return counter + bytes(of: second)
    }

    // MARK: Block function

    /// The signature for sub-command `0x1B` (activation), which also keys the
    /// BLE stream.
    static func activationSignature(uid: [UInt8]) -> [UInt8] {
        signature(uid: uid, x: UInt16(activateSubcommand), y: activationSecret)
    }

    /// Four signature bytes: the first two output words of the block
    /// function, XORed with the constants 0x4163 and 0x4344.
    static func signature(uid: [UInt8], x: UInt16, y: UInt16) -> [UInt8] {
        let block = scramble(seed(uid: uid, x: x, y: y))
        return Bytes.le16Bytes(block[0] ^ 0x4163) + Bytes.le16Bytes(block[1] ^ 0x4344)
    }

    /// The block function's input for an `(x, y)` pair: UID words mixed with
    /// the arguments and the key.
    static func seed(uid: [UInt8], x: UInt16, y: UInt16) -> [UInt16] {
        [
            Bytes.le16(uid, 4) &+ x &+ y,
            Bytes.le16(uid, 2) &+ key[2],
            Bytes.le16(uid, 0) &+ x &* 2,
            0x241A ^ key[3],
        ]
    }

    /// The block function's input when all four words are supplied, as in
    /// the unlock payload.
    static func seed(uid: [UInt8], words: (UInt16, UInt16, UInt16, UInt16)) -> [UInt16] {
        [
            Bytes.le16(uid, 4) &+ words.0,
            Bytes.le16(uid, 2) &+ words.1,
            Bytes.le16(uid, 0) &+ words.2 &+ key[2],
            words.3 &+ key[3],
        ]
    }

    /// The 64-bit block function: eight rounds of a 2-bit shift-and-XOR step.
    static func scramble(_ input: [UInt16]) -> [UInt16] {
        func step(_ value: UInt16) -> UInt16 {
            var result = value >> 2
            if value & 1 != 0 { result ^= key[1] }
            if value & 2 != 0 { result ^= key[0] }
            return result
        }
        let r0 = step(input[0]) ^ input[3]
        let r1 = step(r0) ^ input[2]
        let r2 = step(r1) ^ input[1]
        let r3 = step(r2) ^ input[0]
        let r4 = step(r3)
        let r5 = step(r4 ^ r0)
        let r6 = step(r5 ^ r1)
        let r7 = step(r6 ^ r2)
        return [r3 ^ r7, r2 ^ r6, r1 ^ r5, r0 ^ r4]
    }

    /// The block's four words as eight little-endian bytes.
    static func bytes(of block: [UInt16]) -> [UInt8] {
        block.flatMap(Bytes.le16Bytes)
    }
}
