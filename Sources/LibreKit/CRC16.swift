// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// The CRC that guards the FRAM header, body and footer and every decrypted
/// BLE frame.
///
/// It is CRC-16 with polynomial 0x1021 processed reflected (0x8408), seeded
/// with 0xFFFF and no final XOR, after which the 16-bit result has its bit
/// order reversed. The sensor stores the value little-endian, so
/// ``isValid(_:storedAt:covering:)`` compares it with the two stored bytes
/// read low byte first.
public enum CRC16 {
    /// The Libre CRC of `bytes`.
    public static func libre(_ bytes: some Sequence<UInt8>) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = crc & 1 == 1 ? (crc >> 1) ^ 0x8408 : crc >> 1
            }
        }
        return reversed(crc)
    }

    /// Whether the little-endian CRC stored at `offset` matches the CRC of
    /// `range`.
    public static func isValid(_ bytes: [UInt8], storedAt offset: Int, covering range: Range<Int>) -> Bool {
        guard offset >= 0, offset + 2 <= bytes.count, range.lowerBound >= 0, range.upperBound <= bytes.count else {
            return false
        }
        return libre(bytes[range]) == Bytes.le16(bytes, offset)
    }

    private static func reversed(_ value: UInt16) -> UInt16 {
        var input = value
        var output: UInt16 = 0
        for _ in 0..<16 {
            output = output << 1 | input & 1
            input >>= 1
        }
        return output
    }
}
