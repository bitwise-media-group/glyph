// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// The serial number printed on the sensor, derived from its NFC UID.
///
/// The UID is the ISO 15693 tag identifier in transmission order (least
/// significant byte first, ending `07 E0`). Its six identifying bytes, read
/// most significant first, form a 48-bit number; padded with two zero bits it
/// splits into ten 5-bit digits, each spelled from a 32-character alphabet
/// that drops B, I, O and S. The family nibble from the patch info (3 for
/// Libre 2) is prepended, so Libre 2 serials start with "3".
public enum SensorSerial {
    static let alphabet = Array("0123456789ACDEFGHJKLMNPQRTUVWXYZ")

    /// The printed serial, or `nil` unless `uid` is 8 bytes.
    public static func make(uid: [UInt8], family: Int) -> String? {
        guard uid.count == 8 else { return nil }
        // Most significant first, without the 0xE0 0x07 ISO 15693 header.
        let identifying = uid.reversed().dropFirst(2)
        var value: UInt64 = identifying.reduce(0) { $0 << 8 | UInt64($1) }
        value <<= 2  // pad to 50 bits = ten 5-bit digits
        let digits = (0..<10).map { index in
            alphabet[Int(value >> UInt64(45 - 5 * index) & 0x1F)]
        }
        return String(family) + String(digits)
    }

}

/// Decides whether a discovered BLE peripheral is the paired sensor.
///
/// Older Libre 2 sensors advertise as "ABBOTT" followed by the serial; newer
/// `7F` sensors advertise their MAC address instead. Either way the
/// manufacturer data carries six bytes of the UID (the two after the company
/// identifier), which is the fallback when the name is missing or unexpected.
public struct PeripheralMatcher: Sendable, Hashable {
    public let serial: String
    public let uid: [UInt8]
    /// The MAC the sensor returned when streaming was enabled, most
    /// significant byte first.
    public let mac: [UInt8]?

    public init(serial: String, uid: [UInt8], mac: [UInt8]?) {
        self.serial = serial
        self.uid = uid
        self.mac = mac
    }

    public var expectedName: String { "ABBOTT" + serial }

    public func matches(name: String?, manufacturerData: [UInt8]?) -> Bool {
        if let name {
            let folded = name.uppercased()
            if folded == expectedName.uppercased() { return true }
            if let mac {
                let plain = mac.hexString
                let colons = stride(from: 0, to: plain.count, by: 2).map { offset in
                    let start = plain.index(plain.startIndex, offsetBy: offset)
                    return String(plain[start..<plain.index(start, offsetBy: 2)])
                }.joined(separator: ":")
                if folded == plain || folded == colons { return true }
            }
        }
        if let data = manufacturerData, data.count == 8, uid.count == 8 {
            return Array(data[2..<8]) == Array(uid[0..<6])
        }
        return false
    }
}
