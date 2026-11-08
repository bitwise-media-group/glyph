// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import CoreNFC
import Foundation
import LibreKit
import os

/// Everything one NFC scan learns, enough to stream over BLE.
struct NFCScanResult: Sendable {
    let uid: [UInt8]
    let patchInfo: PatchInfo
    let type: SensorType
    let fram: FRAM
    let serial: String
    /// Most significant byte first.
    let mac: [UInt8]
    let unlockCode: UInt32
    let scanDate: Date
}

enum NFCScanError: LocalizedError, Equatable {
    case unavailable
    case unsupported(UnsupportedSensorError)
    case notStarted
    case ended(SensorState)
    case framInvalid
    case streamingRefused
    case communication(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable: "This iPhone can't read NFC tags."
        case .unsupported(let reason): reason.description
        case .notStarted:
            "This sensor hasn't been started. Start it with the LibreLink app or a Libre reader, then scan it here."
        case .ended(let state):
            state == .failure
                ? "The sensor reports a failure and can't be used." : "This sensor has ended. Apply a new one."
        case .framInvalid: "The sensor's data didn't pass its integrity check. Hold the phone still and scan again."
        case .streamingRefused: "The sensor didn't enable Bluetooth. Scan again."
        case .communication(let detail):
            "Lost contact with the sensor (\(detail)). Hold the phone still and scan again."
        case .cancelled: "Scan cancelled."
        }
    }
}

/// Pairs with a sensor over NFC (ISO 15693):
///
/// 1. custom command `0xA1` → patch info; anything but a European Libre 2
///    or 2 Plus is refused with a reason;
/// 2. 43 FRAM blocks, three per read;
/// 3. UID = the tag identifier reversed;
/// 4. decrypt the FRAM and verify all three CRCs;
/// 5. refuse a sensor that hasn't been started — Glyph never activates
///    sensors — or has ended;
/// 6. `0xA1` sub-command `0x1E` with an unlock code and signature enables
///    BLE streaming; the reply, reversed, is the BLE MAC.
final class NFCSensorReader: NSObject {
    private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "nfc")
    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<NFCScanResult, any Error>?
    private let retries = 3

    func scan() async throws -> NFCScanResult {
        guard NFCTagReaderSession.readingAvailable else { throw NFCScanError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = NFCTagReaderSession(
                configuration: .init(pollingOption: .iso15693), delegate: self, queue: .main)
            session.alertMessage = "Hold the top of your iPhone near the sensor."
            self.session = session
            session.begin()
        }
    }

    private func finish(_ result: Result<NFCScanResult, NFCScanError>) {
        switch result {
        case .success:
            session?.alertMessage = "Sensor paired."
            session?.invalidate()
        case .failure(let error):
            session?.invalidate(errorMessage: error.errorDescription ?? "Scan failed.")
        }
        continuation?.resume(with: result.mapError { $0 as any Error })
        continuation = nil
        session = nil
    }

    private func withRetries<T>(_ label: String, _ operation: () async throws -> T) async throws(NFCScanError) -> T {
        var lastError: (any Error)?
        for attempt in 1...retries {
            do {
                return try await operation()
            } catch {
                lastError = error
                log.error("\(label, privacy: .public) attempt \(attempt) failed: \(error.localizedDescription)")
            }
        }
        throw .communication(lastError?.localizedDescription ?? label)
    }

    private func read(tag: any NFCISO15693Tag, session: NFCTagReaderSession) async throws(NFCScanError) -> NFCScanResult
    {
        try await withRetries("connect") { try await Self.connect(session, to: tag) }

        let infoBytes = try await withRetries("patch info") {
            try await Self.customCommand(tag, code: 0xA1, parameters: Data())
        }
        let patchInfo: PatchInfo
        let type: SensorType
        do {
            patchInfo = try PatchInfo([UInt8](infoBytes))
            type = try SensorType(patchInfo: patchInfo)
        } catch {
            throw .unsupported(error)
        }

        var encrypted: [UInt8] = []
        let blockCount = FRAM.byteCount / 8
        for first in stride(from: 0, to: blockCount, by: 3) {
            let range = NSRange(location: first, length: min(3, blockCount - first))
            let blocks = try await withRetries("read blocks \(first)") { try await Self.readBlocks(tag, range: range) }
            encrypted += blocks.flatMap { [UInt8]($0) }
        }

        let uid = [UInt8](tag.identifier.reversed())
        let fram: FRAM
        do {
            fram = try FRAM(encrypted: encrypted, uid: uid, patchInfo: patchInfo)
        } catch {
            throw .framInvalid
        }
        switch fram.state {
        case .active, .warmingUp: break
        case .notActivated, .unknown: throw .notStarted
        case .expired, .shutdown, .failure: throw .ended(fram.state)
        }

        let unlockCode = UInt32.random(in: 1...UInt32.max)
        let parameters = Libre2Crypto.enableStreamingParameters(uid: uid, patchInfo: patchInfo, unlockCode: unlockCode)
        let reply = try await withRetries("enable streaming") {
            try await Self.customCommand(tag, code: 0xA1, parameters: Data(parameters))
        }
        guard reply.count == 6 else { throw .streamingRefused }

        guard let serial = SensorSerial.make(uid: uid, family: patchInfo.family) else { throw .framInvalid }
        return NFCScanResult(
            uid: uid, patchInfo: patchInfo, type: type, fram: fram, serial: serial, mac: [UInt8](reply.reversed()),
            unlockCode: unlockCode, scanDate: .now)
    }

    // The completion-handler forms, wrapped: their callbacks arrive on the
    // session's queue (main) and only Sendable results cross back, whereas
    // the async forms would send the non-Sendable tag off the main actor.

    private static func connect(_ session: NFCTagReaderSession, to tag: any NFCISO15693Tag) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            session.connect(to: .iso15693(tag)) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private static func customCommand(_ tag: any NFCISO15693Tag, code: Int, parameters: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
            tag.customCommand(requestFlags: .highDataRate, customCommandCode: code, customRequestParameters: parameters)
            {
                response, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: response) }
            }
        }
    }

    private static func readBlocks(_ tag: any NFCISO15693Tag, range: NSRange) async throws -> [Data] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Data], any Error>) in
            tag.readMultipleBlocks(requestFlags: [.highDataRate, .address], blockRange: range) { blocks, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: blocks) }
            }
        }
    }
}

extension NFCSensorReader: @preconcurrency NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) {
        guard let continuation else { return }
        let code = (error as? NFCReaderError)?.code
        let mapped: NFCScanError =
            code == .readerSessionInvalidationErrorUserCanceled
            ? .cancelled : .communication(error.localizedDescription)
        continuation.resume(throwing: mapped)
        self.continuation = nil
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard case .iso15693(let tag) = tags.first else {
            session.restartPolling()
            return
        }
        Task {
            do throws(NFCScanError) {
                finish(.success(try await read(tag: tag, session: session)))
            } catch {
                finish(.failure(error))
            }
        }
    }
}
