// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// Little helpers for the byte layouts the sensor uses: little-endian words
/// and LSB-first bit fields.
enum Bytes {
    /// The little-endian 16-bit word at `offset`.
    static func le16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    /// The little-endian 16-bit word as an `Int`.
    static func le16Int(_ bytes: [UInt8], _ offset: Int) -> Int {
        Int(le16(bytes, offset))
    }

    /// The low and high bytes of `value`, in that order.
    static func le16Bytes(_ value: UInt16) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
    }

    /// The four bytes of `value`, least significant first.
    static func le32Bytes(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    /// Reads a `count`-bit unsigned field starting `bit` bits into the byte at
    /// `byte`. Bits are numbered from the least significant bit of each byte
    /// upwards, and the field's first bit is its least significant one.
    static func bits(_ bytes: [UInt8], byte: Int, bit: Int, count: Int) -> Int {
        var value = 0
        for index in 0..<count {
            let position = byte * 8 + bit + index
            if bytes[position / 8] >> (position % 8) & 1 == 1 {
                value |= 1 << index
            }
        }
        return value
    }

    /// Writes the low `count` bits of `value` into the field ``bits(_:byte:bit:count:)`` reads.
    static func setBits(_ bytes: inout [UInt8], byte: Int, bit: Int, count: Int, to value: Int) {
        for index in 0..<count {
            let position = byte * 8 + bit + index
            let mask = UInt8(1) << (position % 8)
            if value >> index & 1 == 1 {
                bytes[position / 8] |= mask
            } else {
                bytes[position / 8] &= ~mask
            }
        }
    }
}

extension Array where Element == UInt8 {
    /// Parses a hex string (upper or lower case; spaces, colons and newlines
    /// ignored). Returns `nil` for an odd digit count or a non-hex character.
    public init?(hex: String) {
        let digits = hex.filter { !$0.isWhitespace && $0 != ":" }
        guard digits.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = bytes
    }

    /// Upper-case hex with no separators.
    public var hexString: String {
        map { byte in
            let digits = String(byte, radix: 16, uppercase: true)
            return digits.count == 1 ? "0" + digits : digits
        }.joined()
    }
}
