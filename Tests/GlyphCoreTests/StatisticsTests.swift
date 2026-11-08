// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@testable import GlyphCore

struct StatisticsTests {
    @Test func emptyHasNoStatistics() {
        #expect(GlucoseStatistics(mgdL: []) == nil)
    }

    @Test func timeInRangeBands() throws {
        // 10 readings: 1 very low, 1 low, 6 in range, 1 high, 1 very high.
        let values: [Double] = [50, 65, 70, 100, 120, 150, 170, 180, 200, 300]
        let stats = try #require(GlucoseStatistics(mgdL: values))
        #expect(stats.veryLow == 0.1)
        #expect(stats.low == 0.1)
        #expect(stats.inRange == 0.6)
        #expect(stats.high == 0.1)
        #expect(stats.veryHigh == 0.1)
        #expect(abs(stats.belowRange - 0.2) < 1e-12)
        #expect(abs(stats.aboveRange - 0.2) < 1e-12)
        #expect(abs(stats.veryLow + stats.low + stats.inRange + stats.high + stats.veryHigh - 1) < 1e-12)
    }

    @Test func meanSDCVAndGMI() throws {
        let stats = try #require(GlucoseStatistics(mgdL: [100, 120, 140, 160, 180]))
        #expect(stats.mean == 140)
        // sample standard deviation of 100…180 step 20 = sqrt(1000) ≈ 31.62
        #expect(abs(stats.standardDeviation - 1000.0.squareRoot()) < 1e-9)
        #expect(abs(stats.coefficientOfVariation - 22.587) < 0.001)
        // GMI = 3.31 + 0.02392 × 140 = 6.6588 %
        #expect(abs(stats.gmi - 6.6588) < 1e-9)
        #expect(abs(stats.gmiMmolPerMol - 49.27) < 0.01)
    }

    @Test func singleValueHasZeroSpread() throws {
        let stats = try #require(GlucoseStatistics(mgdL: [110]))
        #expect(stats.standardDeviation == 0)
        #expect(stats.coefficientOfVariation == 0)
    }

    @Test func percentilesInterpolate() {
        let values: [Double] = [10, 20, 30, 40, 50]
        #expect(AGPProfile.percentile(values, 0) == 10)
        #expect(AGPProfile.percentile(values, 0.5) == 30)
        #expect(AGPProfile.percentile(values, 0.25) == 20)
        #expect(AGPProfile.percentile(values, 0.1) == 14)
        #expect(AGPProfile.percentile([7], 0.95) == 7)
        #expect(AGPProfile.percentile([], 0.5).isNaN)
    }

    @Test func agpBucketsByTimeOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let midnight = Date(timeIntervalSince1970: 1_700_006_400)  // 2023-11-15 00:00 UTC
        var readings: [(date: Date, mgdL: Double)] = []
        for day in 0..<5 {
            let base = midnight.addingTimeInterval(Double(day) * 86_400)
            readings.append((base.addingTimeInterval(10 * 60), 100 + Double(day) * 10))  // 00:10 → slot 0
            readings.append((base.addingTimeInterval(8 * 3600 + 45 * 60), 200))  // 08:45 → slot 510
        }
        readings.append((midnight.addingTimeInterval(12 * 3600), 150))  // a lone noon reading
        let buckets = AGPProfile.compute(readings, slotMinutes: 30, minimumCount: 3, calendar: calendar)
        #expect(buckets.map(\.minuteOfDay) == [0, 510])
        #expect(buckets[0].median == 120)
        #expect(abs(buckets[0].p5 - 102) < 1e-9)
        #expect(abs(buckets[0].p95 - 138) < 1e-9)
        #expect(buckets[1].p25 == 200)
    }
}
