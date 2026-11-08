// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation

/// One decrypted BLE frame: the sensor sends one roughly every minute.
///
/// Layout of the 44 decrypted bytes: seven 4-byte trend records (bytes
/// 0–27) for 0, 2, 4, 6, 7, 12 and 15 minutes ago; three 4-byte history
/// records (28–39) on the 15-minute grid; the sensor age in minutes
/// (40–41, little-endian); and the CRC of bytes 0–41 (42–43, little-endian).
public struct BLEFrame: Sendable, Hashable {
    public static let encryptedByteCount = 46
    public static let decryptedByteCount = 44
    /// How many minutes before the frame's age each trend record describes.
    public static let trendOffsets = [0, 2, 4, 6, 7, 12, 15]

    public enum Error: Swift.Error, Equatable, Sendable {
        case invalidLength(Int)
        case crcMismatch
    }

    /// Minutes since the sensor started, at the time of the frame.
    public let age: Int
    /// Seven records, newest first; `trend[0]` is "now".
    public let trend: [RawReading]
    /// Three records on the 15-minute grid, newest first.
    public let history: [RawReading]

    public init(decrypted bytes: [UInt8]) throws(Error) {
        guard bytes.count == Self.decryptedByteCount else { throw .invalidLength(bytes.count) }
        guard CRC16.isValid(bytes, storedAt: 42, covering: 0..<42) else { throw .crcMismatch }
        let age = Bytes.le16Int(bytes, 40)
        self.age = age
        trend = Self.trendOffsets.enumerated().map { index, offset in
            RawReading.ble(bytes, at: index * 4, sensorAge: age - offset)
        }
        // History lags by two minutes; the newest record is the last
        // 15-minute boundary at or before `age - 2`.
        let newest = (age - 2) / 15 * 15
        history = (0..<3).map { index in
            RawReading.ble(bytes, at: 28 + index * 4, sensorAge: newest - 15 * index)
        }
    }

    /// Decrypts, CRC-checks and parses a frame as received over BLE.
    public init(encrypted: [UInt8], uid: [UInt8]) throws {
        try self.init(decrypted: Libre2Crypto.decryptBLE(encrypted, uid: uid))
    }

    /// Builds a decrypted payload (with CRC) from seven trend and three
    /// history records, for the simulated sensor and tests. Record ages are
    /// implied by `age`, as on the wire.
    public static func payload(age: Int, trend: [RawReading], history: [RawReading]) -> [UInt8] {
        precondition(trend.count == 7 && history.count == 3, "a frame holds 7 trend and 3 history records")
        var bytes = [UInt8](repeating: 0, count: decryptedByteCount)
        for (index, record) in (trend + history).enumerated() {
            record.writeBLE(into: &bytes, at: index * 4)
        }
        bytes[40] = UInt8(truncatingIfNeeded: age)
        bytes[41] = UInt8(truncatingIfNeeded: age >> 8)
        let crc = Bytes.le16Bytes(CRC16.libre(bytes[0..<42]))
        bytes[42] = crc[0]
        bytes[43] = crc[1]
        return bytes
    }

    /// Every record in the frame, newest first.
    public var records: [RawReading] {
        (trend + history).sorted { $0.sensorAge > $1.sensorAge }
    }
}

/// Collects the notifications from characteristic F002 into 46-byte frames.
///
/// A frame arrives as several notifications (20 + 18 + 8 bytes in
/// practice). Bytes that sit unfinished for longer than `timeout` are
/// discarded, so a dropped notification costs one frame rather than
/// corrupting the next.
public struct BLEFrameAssembler: Sendable {
    public let timeout: TimeInterval
    private var buffer: [UInt8] = []
    private var startedAt: Date?

    public init(timeout: TimeInterval = 3) {
        self.timeout = timeout
    }

    /// Appends one notification's bytes and returns a complete frame once 46
    /// bytes have accumulated.
    public mutating func append(_ chunk: [UInt8], at date: Date) -> [UInt8]? {
        if let startedAt, date.timeIntervalSince(startedAt) > timeout {
            reset()
        }
        if buffer.isEmpty { startedAt = date }
        buffer += chunk
        guard buffer.count >= BLEFrame.encryptedByteCount else { return nil }
        let frame = Array(buffer.prefix(BLEFrame.encryptedByteCount))
        reset()
        return frame
    }

    public mutating func reset() {
        buffer = []
        startedAt = nil
    }
}
