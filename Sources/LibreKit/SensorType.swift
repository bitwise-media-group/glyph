// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

/// The 6 bytes the sensor returns for NFC custom command `0xA1`.
///
/// - byte 0: the product code that identifies the sensor type and region
/// - byte 2: family (high nibble) and security generation (low nibble)
/// - byte 3: region (1 Europe, 2 US, 4 Australia/Canada, 8 rest of world)
/// - bytes 4–5: a little-endian word that seeds the FRAM and streaming crypto
public struct PatchInfo: Sendable, Hashable, Codable {
    public let bytes: [UInt8]

    /// Wraps the `0xA1` response. Libre 3 and later answer with more than 6
    /// bytes, so longer responses are kept whole for ``SensorType`` to reject.
    public init(_ bytes: [UInt8]) throws(UnsupportedSensorError) {
        guard bytes.count >= 6 else { throw .malformedPatchInfo(bytes) }
        self.bytes = bytes
    }

    public var productCode: UInt8 { bytes[0] }
    public var family: Int { Int(bytes[2] >> 4) }
    public var generation: Int { Int(bytes[2] & 0x0F) }
    public var region: SensorRegion { SensorRegion(rawValue: bytes[3]) ?? .unknown }

    /// Bytes 4–5 as a little-endian word.
    var cryptoWord: UInt16 { Bytes.le16(bytes, 4) }
}

public enum SensorRegion: UInt8, Sendable, Codable {
    case unknown = 0
    case europe = 1
    case usa = 2
    case australiaCanada = 4
    case restOfWorld = 8
}

/// The sensors Glyph streams from: European Libre 2 and Libre 2 Plus, which
/// share the BLE protocol and differ only in wear time.
public enum SensorType: String, Sendable, Hashable, Codable, CaseIterable {
    case libre2EU
    case libre2PlusEU

    /// Classifies a patch info, throwing a user-facing reason for anything
    /// Glyph can't stream from.
    ///
    /// Supported product codes: `9D` and `C5` (Libre 2), `C6` (Libre 2 Plus)
    /// and `7F`, which is Libre 2 Plus when the generation nibble is non-zero
    /// and Libre 2 otherwise.
    public init(patchInfo: PatchInfo) throws(UnsupportedSensorError) {
        if patchInfo.bytes.count > 6 { throw .libre3 }
        switch patchInfo.productCode {
        case 0x9D, 0xC5: self = .libre2EU
        case 0xC6: self = .libre2PlusEU
        case 0x7F: self = patchInfo.generation > 0 ? .libre2PlusEU : .libre2EU
        case 0xDF, 0xA2: throw .libre1
        case 0xE5, 0xE6: throw .libreUS14Day
        case 0x70: throw .libreProH
        case 0x2B, 0x2C: throw .libre2Gen2
        case 0x76:
            switch (patchInfo.bytes[3], patchInfo.family) {
            case (0x02, _): throw .libre2US
            case (0x04, _): throw .libre2CA
            case (_, 7): throw .libreSense
            default: throw .unknown(patchInfo.productCode)
            }
        default: throw .unknown(patchInfo.productCode)
        }
    }

    public var displayName: String {
        switch self {
        case .libre2EU: "FreeStyle Libre 2"
        case .libre2PlusEU: "FreeStyle Libre 2 Plus"
        }
    }

    /// Wear time in minutes, used when the FRAM doesn't state one: 14.5 days
    /// for Libre 2 (14 days plus the 12-hour grace period) and 15.5 days for
    /// Libre 2 Plus.
    public var defaultMaxAge: Int {
        switch self {
        case .libre2EU: 20_880
        case .libre2PlusEU: 22_320
        }
    }

    /// Minutes after start during which readings are unreliable and are
    /// neither shown nor stored.
    public static let warmUpMinutes = 60
}

/// Why a scanned sensor can't be used, phrased for the user.
public enum UnsupportedSensorError: Error, Equatable, Sendable, CustomStringConvertible {
    case malformedPatchInfo([UInt8])
    case libre1
    case libreUS14Day
    case libreProH
    case libre2US
    case libre2CA
    case libre2Gen2
    case libreSense
    case libre3
    case unknown(UInt8)

    public var description: String {
        switch self {
        case .malformedPatchInfo(let bytes):
            "The sensor sent an unexpected response (\(bytes.hexString)). Try scanning again."
        case .libre1: "FreeStyle Libre 1 sensors aren't supported: they have no Bluetooth."
        case .libreUS14Day: "The US FreeStyle Libre 14-day sensor isn't supported."
        case .libreProH: "FreeStyle Libre Pro/H sensors aren't supported."
        case .libre2US: "The US Libre 2 isn't supported. Glyph works with the European Libre 2 and Libre 2 Plus."
        case .libre2CA: "The Canadian Libre 2 isn't supported. Glyph works with the European Libre 2 and Libre 2 Plus."
        case .libre2Gen2: "Second-generation (US and Latin American) Libre 2 sensors aren't supported."
        case .libreSense: "Libre Sense sensors aren't supported."
        case .libre3: "FreeStyle Libre 3 sensors aren't supported."
        case .unknown(let code):
            "This sensor (type \(code < 0x10 ? "0" : "")\(String(code, radix: 16, uppercase: true))) isn't supported."
        }
    }
}
