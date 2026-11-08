// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit

/// The small file the app writes to the App Group for the widgets: the
/// latest reading and the last three hours. Cheaper for an extension than
/// opening the SwiftData store.
public struct WidgetSnapshot: Sendable, Hashable, Codable {
    public struct Point: Sendable, Hashable, Codable {
        public let date: Date
        public let mgdL: Double

        public init(date: Date, mgdL: Double) {
            self.date = date
            self.mgdL = mgdL
        }
    }

    public var latest: Point?
    /// The last three hours, oldest first.
    public var recent: [Point]
    public var trend: TrendArrow
    public var deltaMgdL: Double?
    public var unit: GlucoseUnit
    public var target: TargetRange
    public var sensorExpiry: Date?
    public var updatedAt: Date

    public static let window: TimeInterval = 3 * 60 * 60
    /// After this long without a reading the value is shown as stale.
    public static let staleAfter: TimeInterval = 5 * 60

    public init(
        latest: Point?, recent: [Point], trend: TrendArrow, deltaMgdL: Double?, unit: GlucoseUnit,
        target: TargetRange, sensorExpiry: Date?, updatedAt: Date
    ) {
        self.latest = latest
        self.recent = recent
        self.trend = trend
        self.deltaMgdL = deltaMgdL
        self.unit = unit
        self.target = target
        self.sensorExpiry = sensorExpiry
        self.updatedAt = updatedAt
    }

    public static let empty = WidgetSnapshot(
        latest: nil, recent: [], trend: .unknown, deltaMgdL: nil, unit: .mmolL, target: .standard,
        sensorExpiry: nil, updatedAt: .distantPast)

    public func isStale(at date: Date) -> Bool {
        guard let latest else { return true }
        return date.timeIntervalSince(latest.date) > Self.staleAfter
    }

    /// Keeps only `window` before `now`, oldest first.
    public static func trimmed(_ points: [Point], now: Date) -> [Point] {
        points.filter { now.timeIntervalSince($0.date) <= window && $0.date <= now }.sorted { $0.date < $1.date }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }
}
