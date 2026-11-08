// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import SwiftData
import SwiftUI

/// Fourteen days of readings.
///
/// Primary pane: a horizontally scrollable chart with a 3/6/12/24-hour
/// window and a scrub callout. Secondary pane: 14-day statistics and the
/// ambulatory glucose profile. The window, scroll position and scrubbed
/// time are scene storage, so folding or unfolding mid-scrub keeps them.
struct HistoryView: View {
    static let days = 14
    static let windows = [3, 6, 12, 24]

    @Environment(AppSettings.self) private var settings
    @Query private var readings: [GlucoseReading]
    @SceneStorage("history.hours") private var hours = 6
    @SceneStorage("history.scroll") private var scrollTime: Double = 0
    @SceneStorage("history.selection") private var selectionTime: Double = 0

    init() {
        let since = Date.now.addingTimeInterval(-Double(Self.days) * 86_400)
        _readings = Query(filter: #Predicate<GlucoseReading> { $0.date >= since }, sort: \.date)
    }

    var body: some View {
        NavigationStack {
            SectionPanes {
                Picker("Window", selection: $hours) {
                    ForEach(Self.windows, id: \.self) { Text("\($0) h").tag($0) }
                }
                .pickerStyle(.segmented)

                Card {
                    GlucoseChart(
                        points: points, unit: settings.unit, target: settings.target,
                        lowThreshold: settings.alerts.low.isEnabled ? settings.alerts.low.threshold : nil,
                        highThreshold: settings.alerts.high.isEnabled ? settings.alerts.high.threshold : nil,
                        domain: domain, selection: selection
                    )
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: Double(hours) * 3600)
                    .chartScrollPosition(x: scrollPosition)
                    .expandingHeight(aspectRatio: 1.6)
                }
            } secondary: {
                StatisticsCard(readings: readings)
                Card(title: "Daily pattern (\(Self.days) days)") {
                    AGPChart(readings: readings.map { (date: $0.date, mgdL: $0.mgdL) })
                        .expandingHeight(aspectRatio: 2)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Five-minute means: enough detail at a 3-hour window, light enough to
    /// scroll fourteen days.
    private var points: [GlucosePoint] {
        var buckets: [Int: (sum: Double, count: Int)] = [:]
        for reading in readings {
            let key = Int(reading.date.timeIntervalSince1970 / 300)
            buckets[key, default: (0, 0)].sum += reading.mgdL
            buckets[key, default: (0, 0)].count += 1
        }
        return buckets.keys.sorted().map { key in
            let bucket = buckets[key]!
            return GlucosePoint(
                date: Date(timeIntervalSince1970: Double(key) * 300 + 150), mgdL: bucket.sum / Double(bucket.count))
        }
    }

    private var domain: ClosedRange<Date> {
        let now = Date.now
        let first = readings.first?.date ?? now.addingTimeInterval(-Double(hours) * 3600)
        return min(first, now.addingTimeInterval(-Double(hours) * 3600))...now
    }

    /// The leading edge of the visible window; defaults to the latest data.
    private var scrollPosition: Binding<Date> {
        Binding {
            scrollTime == 0
                ? Date.now.addingTimeInterval(-Double(hours) * 3600) : Date(timeIntervalSince1970: scrollTime)
        } set: {
            scrollTime = $0.timeIntervalSince1970
        }
    }

    private var selection: Binding<Date?> {
        Binding {
            selectionTime == 0 ? nil : Date(timeIntervalSince1970: selectionTime)
        } set: {
            selectionTime = $0?.timeIntervalSince1970 ?? 0
        }
    }
}

/// Average, GMI, time in ranges and variability over the period.
struct StatisticsCard: View {
    @Environment(AppSettings.self) private var settings
    var readings: [GlucoseReading]

    var body: some View {
        Card(title: "Last \(HistoryView.days) days") {
            if let stats = GlucoseStatistics(mgdL: readings.map(\.mgdL), target: settings.target) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        metric("Average", settings.unit.format(mgdL: stats.mean, withUnit: true))
                        metric("GMI", stats.gmi.formatted(.number.precision(.fractionLength(1))) + " %")
                    }
                    GridRow {
                        metric("Time in range", percent(stats.inRange))
                        metric(
                            "Variability (CV)",
                            stats.coefficientOfVariation.formatted(.number.precision(.fractionLength(0))) + " %")
                    }
                    GridRow {
                        metric("Below range", percent(stats.belowRange))
                        metric("Above range", percent(stats.aboveRange))
                    }
                }
                RangeBar(stats: stats)
                Text("\(stats.count) readings. GMI estimates HbA1c from the average; it is not a lab result.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No readings in this period").foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
