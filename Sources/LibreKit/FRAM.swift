// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// The sensor's state byte (FRAM byte 4).
public enum SensorState: UInt8, Sendable, Codable {
    case notActivated = 1
    case warmingUp = 2
    case active = 3
    /// Past its wear time but still in the 12-hour grace period.
    case expired = 4
    case shutdown = 5
    case failure = 6
    case unknown = 0

    public init(byte: UInt8) {
        self = SensorState(rawValue: byte) ?? .unknown
    }
}

/// The six factory-calibration parameters stored in the FRAM.
///
/// `i1` and `i2` come from the header (byte 2); `i3`–`i6` from the footer
/// block at 0x150. ``FactoryCalibration`` turns them into a
/// ``GlucoseConverter``.
public struct CalibrationInfo: Sendable, Hashable, Codable {
    public let i1: Int
    public let i2: Int
    public let i3: Int
    public let i4: Int
    public let i5: Int
    public let i6: Int

    public init(i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int) {
        self.i1 = i1
        self.i2 = i2
        self.i3 = i3
        self.i4 = i4
        self.i5 = i5
        self.i6 = i6
    }
}

/// A decrypted, CRC-checked 344-byte FRAM image.
///
/// Layout: a 24-byte header (CRC, state, failure details, `i1`/`i2`), a
/// 296-byte body (CRC, ring indices, 16 one-minute trend records, 32
/// fifteen-minute history records, age) and a 24-byte footer (CRC, region,
/// max life, `i3`–`i6`). Each section starts with the little-endian CRC of
/// the rest of the section; Glyph refuses an image whose CRCs don't match.
public struct FRAM: Sendable, Hashable {
    public static let byteCount = 344

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidLength(Int)
        case headerCRC
        case bodyCRC
        case footerCRC
    }

    public let bytes: [UInt8]

    public init(decrypted bytes: [UInt8]) throws(Error) {
        guard bytes.count == Self.byteCount else { throw .invalidLength(bytes.count) }
        guard CRC16.isValid(bytes, storedAt: 0, covering: 2..<24) else { throw .headerCRC }
        guard CRC16.isValid(bytes, storedAt: 24, covering: 26..<320) else { throw .bodyCRC }
        guard CRC16.isValid(bytes, storedAt: 320, covering: 322..<344) else { throw .footerCRC }
        self.bytes = bytes
    }

    /// Decrypts and validates an image read over NFC.
    public init(encrypted: [UInt8], uid: [UInt8], patchInfo: PatchInfo) throws {
        try self.init(decrypted: Libre2Crypto.decryptFRAM(encrypted, uid: uid, patchInfo: patchInfo))
    }

    public var state: SensorState { SensorState(byte: bytes[4]) }

    /// Minutes since the sensor started.
    public var age: Int { Bytes.le16Int(bytes, 316) }

    /// Wear time in minutes as the sensor states it, or `nil` if unset.
    public var maxLife: Int? {
        let value = Bytes.le16Int(bytes, 326)
        return value > 0 ? value : nil
    }

    public var region: SensorRegion { SensorRegion(rawValue: bytes[323]) ?? .unknown }

    public var calibrationInfo: CalibrationInfo {
        let negativeI3 = Bytes.bits(bytes, byte: 0x150, bit: 33, count: 1) == 1
        let i3 = Bytes.bits(bytes, byte: 0x150, bit: 0, count: 8)
        return CalibrationInfo(
            i1: Bytes.bits(bytes, byte: 2, bit: 0, count: 3),
            i2: Bytes.bits(bytes, byte: 2, bit: 3, count: 10),
            i3: negativeI3 ? -i3 : i3,
            i4: Bytes.bits(bytes, byte: 0x150, bit: 8, count: 14),
            i5: Bytes.bits(bytes, byte: 0x150, bit: 40, count: 12) << 2,
            i6: Bytes.bits(bytes, byte: 0x150, bit: 52, count: 12) << 2)
    }

    /// The last 16 one-minute records, newest first. Byte 26 is the index of
    /// the next slot the sensor will write in its 16-record ring.
    public var trend: [RawReading] {
        let next = Int(bytes[26])
        return (0..<16).map { minutesAgo in
            let slot = (next - 1 - minutesAgo + 32) % 16
            return RawReading.fram(bytes, at: 28 + slot * 6, sensorAge: age - minutesAgo)
        }
    }

    /// The last 32 fifteen-minute records, newest first. Byte 27 is the next
    /// slot in the 32-record ring. History lags the age by 3–17 minutes: the
    /// newest record is for age `age - ((age - 3) % 15 + 3)`.
    public var history: [RawReading] {
        let next = Int(bytes[27])
        let newest = age - ((age - 3) % 15 + 3)
        return (0..<32).map { index in
            let slot = (next - 1 - index + 64) % 32
            return RawReading.fram(bytes, at: 124 + slot * 6, sensorAge: newest - index * 15)
        }
    }
}
