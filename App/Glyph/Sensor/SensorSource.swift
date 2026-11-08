// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit

/// The Bluetooth link as the UI describes it.
enum LinkState: Equatable, Sendable {
    case idle
    case poweredOff
    case unauthorized
    case scanning
    case connecting
    case connected
    case disconnected

    var label: String {
        switch self {
        case .idle: "Idle"
        case .poweredOff: "Bluetooth off"
        case .unauthorized: "Bluetooth not allowed"
        case .scanning: "Searching"
        case .connecting: "Waiting for sensor"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
    }
}

/// Everything a sensor source reports.
enum SensorEvent: Sendable {
    case link(LinkState)
    /// A decrypted, CRC-checked frame and the bytes as received.
    case frame(BLEFrame, encrypted: [UInt8], arrival: Date)
    /// Readings that didn't come from a live frame (FRAM back-fill at
    /// pairing, simulator history).
    case samples([GlucoseSample])
    case signal(rssi: Int)
    /// CoreBluetooth's identifier for the sensor, to reconnect directly next
    /// time.
    case peripheralIdentified(UUID)
    case failure(String)
}

/// Hands out the BLE unlock counter. Implementations must persist the new
/// value before returning it: the sensor rejects a reused count.
protocol UnlockCounter: AnyObject {
    func nextUnlockCount() -> UInt16
}

/// A stream of sensor events for one paired sensor: the real Libre 2 over
/// Bluetooth, or the simulator.
protocol SensorSource: AnyObject {
    /// One stream for the source's lifetime; ``SensorController`` is its
    /// only consumer.
    var events: AsyncStream<SensorEvent> { get }
    func start(_ pairing: SensorPairing)
    func stop()
}
