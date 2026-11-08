// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import HealthKit
import LibreKit
import os

/// Writes blood glucose to Health. Write-only: Glyph never reads Health.
///
/// Each sample carries a sync identifier of serial + sensor minute (the
/// sensor's own clock, so a re-sent or back-filled reading maps to the same
/// identifier however it was timestamped) and a sync version, so Health
/// replaces rather than duplicates on a re-send.
final class HealthKitWriter {
    private let store = HKHealthStore()
    private let type = HKQuantityType(.bloodGlucose)
    private let unit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "health")

    static let syncVersion = 1

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var isAuthorized: Bool { store.authorizationStatus(for: type) == .sharingAuthorized }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [type], read: [])
        } catch {
            log.error("authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        return isAuthorized
    }

    /// Saves `samples` as one batch.
    func write(_ samples: [GlucoseSample], serial: String) async {
        guard isAvailable, isAuthorized, !samples.isEmpty else { return }
        let device = HKDevice(
            name: "FreeStyle Libre 2", manufacturer: "Abbott", model: nil, hardwareVersion: nil, firmwareVersion: nil,
            softwareVersion: nil, localIdentifier: serial, udiDeviceIdentifier: nil)
        let objects = samples.map { sample in
            HKQuantitySample(
                type: type, quantity: HKQuantity(unit: unit, doubleValue: sample.mgdL), start: sample.date,
                end: sample.date, device: device,
                metadata: [
                    HKMetadataKeySyncIdentifier: "\(serial)-\(sample.sensorAge)",
                    HKMetadataKeySyncVersion: Self.syncVersion,
                    HKMetadataKeyWasUserEntered: false,
                ])
        }
        do {
            try await store.save(objects)
        } catch {
            log.error("save of \(objects.count) samples failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
