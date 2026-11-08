// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit
import Testing

@testable import GlyphCore

struct ReadingMergeTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func sample(_ age: Int, _ mgdL: Double, _ kind: GlucoseSample.Kind = .trend) -> GlucoseSample {
        GlucoseSample(
            sensorAge: age, date: start.addingTimeInterval(Double(age) * 60), mgdL: mgdL, raw: 1000,
            rawTemperature: 6400, kind: kind)
    }

    @Test func keepsOnlyUnstoredMinutes() {
        let incoming = [sample(600, 100), sample(598, 99), sample(596, 98), sample(594, 97)]
        let fresh = ReadingMerge.newSamples(incoming, existingAges: [598, 596])
        #expect(fresh.map(\.sensorAge) == [600, 594])
    }

    @Test func backFillsAGapAfterReconnecting() {
        // Stored up to age 580; the phone was away; this frame covers 585…600.
        let existing = Set(560...580)
        let frame = [0, 2, 4, 6, 7, 12, 15].map { sample(600 - $0, 100) } + [sample(585, 100, .history)]
        let fresh = ReadingMerge.newSamples(frame, existingAges: existing)
        #expect(fresh.map(\.sensorAge) == [600, 598, 596, 594, 593, 588, 585])
    }

    @Test func trendWinsOverHistoryForTheSameMinute() {
        let fresh = ReadingMerge.newSamples(
            [sample(585, 120, .history), sample(585, 118, .trend), sample(585, 121, .history)], existingAges: [])
        #expect(fresh.count == 1)
        #expect(fresh.first?.kind == .trend)
        #expect(fresh.first?.mgdL == 118)
    }

    @Test func deltaUsesTheReadingAboutFiveMinutesEarlier() {
        let now = start
        let history: [(date: Date, mgdL: Double)] = [
            (now.addingTimeInterval(-2 * 60), 108), (now.addingTimeInterval(-4 * 60), 106),
            (now.addingTimeInterval(-6 * 60), 104), (now.addingTimeInterval(-15 * 60), 90),
        ]
        // -4 and -6 are equally close to -5; either gives a sensible delta.
        let delta = ReadingMerge.delta(current: (now, 110), history: history)
        #expect(delta == 4 || delta == 6)
        #expect(ReadingMerge.delta(current: (now, 110), history: [(now.addingTimeInterval(-15 * 60), 90)]) == nil)
    }

    @Test func throttleAllowsOnePerInterval() {
        var throttle = Throttle(interval: 300)
        let fired = [0, 60, 299, 300].map { throttle.shouldFire(at: start.addingTimeInterval($0)) }
        #expect(fired == [true, false, false, true])
    }
}

struct WidgetSnapshotTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func roundTrips() throws {
        let snapshot = WidgetSnapshot(
            latest: .init(date: now, mgdL: 104), recent: [.init(date: now, mgdL: 104)], trend: .risingSlightly,
            deltaMgdL: 3, unit: .mmolL, target: .standard, sensorExpiry: now.addingTimeInterval(86_400),
            updatedAt: now)
        #expect(try WidgetSnapshot.decode(snapshot.encoded()) == snapshot)
    }

    @Test func staleAfterFiveMinutes() {
        var snapshot = WidgetSnapshot.empty
        #expect(snapshot.isStale(at: now))
        snapshot.latest = .init(date: now, mgdL: 100)
        #expect(!snapshot.isStale(at: now.addingTimeInterval(299)))
        #expect(snapshot.isStale(at: now.addingTimeInterval(301)))
    }

    @Test func trimsToThreeHoursOldestFirst() {
        let points = [
            WidgetSnapshot.Point(date: now, mgdL: 1), .init(date: now.addingTimeInterval(-4 * 3600), mgdL: 2),
            .init(date: now.addingTimeInterval(-3600), mgdL: 3),
        ]
        #expect(WidgetSnapshot.trimmed(points, now: now).map(\.mgdL) == [3, 1])
    }
}
