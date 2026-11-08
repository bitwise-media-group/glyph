// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import CoreBluetooth
import Foundation
import LibreKit
import os

/// The Libre 2 over Bluetooth.
///
/// The sensor accepts one client. After connecting, Glyph discovers service
/// FDE3, subscribes to F002 and immediately writes the 12-byte unlock
/// payload to F001 — without waiting for the subscription to be confirmed,
/// or the sensor drops the link. Frames arrive as F002 notifications, about
/// once a minute, and the sensor disconnects after each one; Glyph re-issues
/// `connect` at once and iOS keeps it pending until the next advertisement.
///
/// The central uses a restoration identifier, so iOS relaunches Glyph in the
/// background when a pending connection completes; `willRestoreState`
/// re-attaches the peripheral. Callbacks run on the main queue, which keeps
/// the unlock counter's save-before-write simple; the traffic is one small
/// frame a minute.
final class Libre2Peripheral: NSObject, SensorSource {
    static let restoreIdentifier = "uk.co.bitwisemedia.glyph.central"
    static let service = CBUUID(string: "FDE3")
    static let writeCharacteristic = CBUUID(string: "F001")
    static let notifyCharacteristic = CBUUID(string: "F002")

    let events: AsyncStream<SensorEvent>
    private let continuation: AsyncStream<SensorEvent>.Continuation
    private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "ble")

    private weak var unlockCounter: (any UnlockCounter)?
    private lazy var central = CBCentralManager(
        delegate: self, queue: nil,
        options: [
            CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier,
            CBCentralManagerOptionShowPowerAlertKey: true,
        ])
    private var pairing: SensorPairing?
    private var peripheral: CBPeripheral?
    private var assembler = BLEFrameAssembler(timeout: 3)

    init(unlockCounter: any UnlockCounter) {
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.unlockCounter = unlockCounter
        super.init()
        _ = central  // created now, not on first use, so restoration can reach it at launch
    }

    func start(_ pairing: SensorPairing) {
        if self.pairing?.serial != pairing.serial { peripheral = nil }
        self.pairing = pairing
        connectIfPossible()
    }

    func stop() {
        pairing = nil
        central.stopScan()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        assembler.reset()
        continuation.yield(.link(.idle))
    }

    /// Prefers, in order: a peripheral iOS restored, the saved identifier, a
    /// connection another app on the phone holds, and finally a scan.
    private func connectIfPossible() {
        guard let pairing else { return }
        switch central.state {
        case .poweredOn: break
        case .poweredOff:
            continuation.yield(.link(.poweredOff))
            return
        case .unauthorized:
            continuation.yield(.link(.unauthorized))
            return
        default: return
        }

        if let peripheral, pairing.peripheralIdentifier == nil || peripheral.identifier == pairing.peripheralIdentifier
        {
            connect(peripheral)
        } else if let id = pairing.peripheralIdentifier,
            let known = central.retrievePeripherals(withIdentifiers: [id]).first
        {
            connect(known)
        } else if let connected = central.retrieveConnectedPeripherals(withServices: [Self.service])
            .first(where: { pairing.matcher.matches(name: $0.name, manufacturerData: nil) })
        {
            connect(connected)
        } else {
            log.info("scanning for \(pairing.matcher.expectedName, privacy: .public)")
            central.scanForPeripherals(withServices: [Self.service], options: nil)
            continuation.yield(.link(.scanning))
        }
    }

    private func connect(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        // A pending connect never times out: iOS completes it the next time
        // the sensor advertises, even with Glyph suspended.
        central.connect(peripheral, options: nil)
        continuation.yield(.link(.connecting))
    }

    private func unlock(_ peripheral: CBPeripheral, using characteristic: CBCharacteristic) {
        guard let pairing, let counter = unlockCounter else { return }
        let count = counter.nextUnlockCount()  // saved before the write, by contract
        let payload = Libre2Crypto.streamingUnlockPayload(
            uid: pairing.uid, patchInfo: pairing.patchInfo, unlockCode: pairing.unlockCode, unlockCount: count)
        peripheral.writeValue(Data(payload), for: characteristic, type: .withResponse)
    }

    private func received(_ value: Data) {
        guard let pairing, let frame = assembler.append([UInt8](value), at: .now) else { return }
        do {
            let parsed = try BLEFrame(encrypted: frame, uid: pairing.uid)
            continuation.yield(.frame(parsed, encrypted: frame, arrival: .now))
        } catch {
            log.error("dropped frame: \(String(describing: error), privacy: .public)")
            continuation.yield(.failure("A frame from the sensor failed its check and was dropped."))
        }
    }
}

extension Libre2Peripheral: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.info("central state \(central.state.rawValue)")
        connectIfPossible()
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else {
            return
        }
        log.info("restored peripheral \(restored.identifier, privacy: .public)")
        peripheral = restored
        restored.delegate = self
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let pairing else { return }
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let manufacturer = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data).map { [UInt8]($0) }
        guard pairing.matcher.matches(name: name, manufacturerData: manufacturer) else { return }
        central.stopScan()
        continuation.yield(.peripheralIdentified(peripheral.identifier))
        continuation.yield(.signal(rssi: RSSI.intValue))
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        assembler.reset()
        continuation.yield(.link(.connected))
        continuation.yield(.peripheralIdentified(peripheral.identifier))
        peripheral.discoverServices([Self.service])
        peripheral.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        log.error("connect failed: \(String(describing: error), privacy: .public)")
        reconnect(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?
    ) {
        continuation.yield(.link(.disconnected))
        reconnect(peripheral)
    }

    /// The sensor drops the link after every frame; queue the next connect.
    private func reconnect(_ peripheral: CBPeripheral) {
        guard pairing != nil, peripheral.identifier == self.peripheral?.identifier else { return }
        connect(peripheral)
    }
}

extension Libre2Peripheral: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        for service in peripheral.services ?? [] where service.uuid == Self.service {
            peripheral.discoverCharacteristics([Self.writeCharacteristic, Self.notifyCharacteristic], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?
    ) {
        let characteristics = service.characteristics ?? []
        if let notify = characteristics.first(where: { $0.uuid == Self.notifyCharacteristic }) {
            peripheral.setNotifyValue(true, for: notify)
        }
        if let write = characteristics.first(where: { $0.uuid == Self.writeCharacteristic }) {
            unlock(peripheral, using: write)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?)
    {
        guard characteristic.uuid == Self.notifyCharacteristic, let value = characteristic.value else { return }
        received(value)
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        if error == nil { continuation.yield(.signal(rssi: RSSI.intValue)) }
    }
}
