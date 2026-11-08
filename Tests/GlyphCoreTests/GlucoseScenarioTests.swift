// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Foundation
import LibreKit
import Testing

@testable import GlyphCore

struct GlucoseScenarioTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// The last 15 minutes as the app sees them: one reading a minute.
    func recent(_ scenario: GlucoseScenario) -> [(date: Date, mgdL: Double)] {
        let end = now.addingTimeInterval(-Double(scenario.minutesSinceLastReading) * 60)
        return (0...15).map { minutesAgo in
            let date = end.addingTimeInterval(-Double(minutesAgo) * 60)
            return (date, scenario.mgdL(at: date, now: now))
        }
    }

    @Test(arguments: [
        (GlucoseScenario.inRange, GlucoseLevel.inRange, TrendArrow.flat),
        (.high, .high, .flat),
        (.low, .low, .flat),
        (.urgentLow, .urgentLow, .fallingSlightly),
        (.risingFast, .inRange, .risingQuickly),
        (.fallingFast, .inRange, .falling),
        (.signalLost, .inRange, .flat),
    ])
    func scenarioShowsWhatItsNameSays(scenario: GlucoseScenario, level: GlucoseLevel, arrow: TrendArrow) throws {
        let points = recent(scenario)
        let latest = try #require(points.first)
        #expect(GlucoseLevel(mgdL: latest.mgdL, target: .standard) == level)
        #expect(TrendArrow(rate: Trend.rate(of: points)) == arrow)
    }

    @Test(arguments: GlucoseScenario.allCases)
    func sameNowSameReadings(scenario: GlucoseScenario) {
        let date = now.addingTimeInterval(-3 * 86_400 - 1234)
        #expect(scenario.mgdL(at: date, now: now) == scenario.mgdL(at: date, now: now))
        #expect((40...400).contains(scenario.mgdL(at: date, now: now)))
    }

    @Test func historyFollowsTheSharedBackground() {
        // Well before the ending, every live scenario shows the same day.
        let date = now.addingTimeInterval(-2 * 86_400)
        let values = Set(GlucoseScenario.allCases.map { $0.mgdL(at: date, now: now) })
        #expect(values.count == 1)
    }

    @Test(arguments: [GlucoseScenario.risingFast, .fallingFast, .urgentLow])
    func fastScenariosApproachFromAPlausibleValue(scenario: GlucoseScenario) {
        // No plunge to the floor or spike to the ceiling on the way in.
        let values = (16...180).map { scenario.mgdL(at: now.addingTimeInterval(Double(-$0) * 60), now: now) }
        #expect(values.allSatisfy { $0 > 54 && $0 < 250 })
    }

    @Test func sensorStates() {
        #expect(GlucoseScenario.noSensor.sensorAge == nil)
        #expect(GlucoseScenario.warmingUp.sensorAge.map { $0 < 3600 } == true)
        #expect(GlucoseScenario.expired.sensorAge.map { $0 > Double(SensorType.libre2EU.defaultMaxAge) * 60 } == true)
        #expect(GlucoseScenario.signalLost.minutesSinceLastReading > 5)
        #expect(!GlucoseScenario.signalLost.isLive)
    }
}
