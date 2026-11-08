// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import LibreKit
import SwiftData
import SwiftUI

/// The current reading and today at a glance.
///
/// Primary pane: the value in the user's unit, trend arrow, delta and age,
/// over a three-hour chart. Secondary pane: time in range today, sensor days
/// left and the last 15 readings.
struct NowView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ReadingPipeline.self) private var pipeline
    @Environment(SensorController.self) private var controller
    @Query private var readings: [GlucoseReading]

    init() {
        let since = Date.now.addingTimeInterval(-24 * 3600)
        _readings = Query(filter: #Predicate<GlucoseReading> { $0.date >= since }, sort: \.date, order: .reverse)
    }

    var body: some View {
        NavigationStack {
            SectionPanes {
                CurrentReadingCard(current: pipeline.current, phase: controller.phase)
                Card(title: "Last 3 hours") {
                    GlucoseChart(
                        points: points(within: 3 * 3600), unit: settings.unit, target: settings.target,
                        lowThreshold: settings.alerts.low.isEnabled ? settings.alerts.low.threshold : nil,
                        highThreshold: settings.alerts.high.isEnabled ? settings.alerts.high.threshold : nil,
                        domain: Date.now.addingTimeInterval(-3 * 3600)...Date.now
                    )
                    .expandingHeight(aspectRatio: 2)
                }
            } secondary: {
                PaneStack {
                    TimeInRangeTodayCard(readings: todayReadings)
                    SensorLifeCard(pairing: controller.pairing)
                }
                RecentReadingsCard(readings: Array(readings.prefix(15)))
            }
            .navigationTitle("Now")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func points(within interval: TimeInterval) -> [GlucosePoint] {
        let since = Date.now.addingTimeInterval(-interval)
        return readings.lazy.filter { $0.date >= since }.map { GlucosePoint(date: $0.date, mgdL: $0.mgdL) }.reversed()
    }

    private var todayReadings: [GlucoseReading] {
        let start = Calendar.current.startOfDay(for: .now)
        return readings.filter { $0.date >= start }
    }
}

/// The big number.
struct CurrentReadingCard: View {
    @Environment(AppSettings.self) private var settings
    var current: CurrentGlucose?
    var phase: SensorController.Phase

    var body: some View {
        Card {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let isStale =
                    current.map { context.date.timeIntervalSince($0.date) > WidgetSnapshot.staleAfter } ?? true
                VStack(alignment: .leading) {
                    GlucoseValueLabel(
                        mgdL: current?.mgdL, trend: current?.trend ?? .unknown, unit: settings.unit,
                        target: settings.target, isStale: isStale)
                    HStack {
                        if let delta = current?.deltaMgdL {
                            Label(
                                "\(settings.unit.formatDelta(mgdL: delta)) \(settings.unit.symbol)",
                                systemImage: "plusminus")
                        }
                        if let date = current?.date {
                            Label(age(of: date, at: context.date), systemImage: "clock")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let message = statusMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func age(of date: Date, at now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        return minutes < 1 ? "Just now" : "\(minutes) min ago"
    }

    private var statusMessage: String? {
        switch phase {
        case .noSensor: "No sensor paired. Scan one on the Sensor tab."
        case .warmingUp(let minutes): "Sensor warming up: readings in \(minutes) min."
        case .signalLost: "Signal lost. Keep your phone near the sensor."
        case .expired: "Sensor ended. Scan a new one."
        case .failed(let message): message
        case .connecting: current == nil ? "Waiting for the first reading…" : nil
        case .scanning, .streaming: nil
        }
    }
}

struct TimeInRangeTodayCard: View {
    @Environment(AppSettings.self) private var settings
    var readings: [GlucoseReading]

    var body: some View {
        Card(title: "Today") {
            if let stats = GlucoseStatistics(mgdL: readings.map(\.mgdL), target: settings.target) {
                Text(stats.inRange, format: .percent.precision(.fractionLength(0)))
                    .font(.largeTitle.weight(.semibold).monospacedDigit())
                Text(
                    "in range \(settings.unit.format(mgdL: settings.target.lower))–\(settings.unit.format(mgdL: settings.target.upper, withUnit: true))"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                RangeBar(stats: stats)
            } else {
                Text("No readings yet today")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A stacked bar of time below, in and above range: as tall as a line of
/// caption text, with each segment's width a fraction of the bar's.
struct RangeBar: View {
    var stats: GlucoseStatistics

    var body: some View {
        Text(verbatim: " ")
            .font(.caption2)
            .frame(maxWidth: .infinity)
            .hidden()
            .overlay {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        segment(stats.veryLow, .red, proxy.size.width)
                        segment(stats.low, .orange, proxy.size.width)
                        segment(stats.inRange, .green, proxy.size.width)
                        segment(stats.high, .yellow, proxy.size.width)
                        segment(stats.veryHigh, .orange.mix(with: .yellow, by: 0.5), proxy.size.width)
                    }
                }
            }
            .clipShape(.capsule)
            .accessibilityElement()
            .accessibilityLabel(
                "Below range \(Int((stats.belowRange * 100).rounded())) percent, in range \(Int((stats.inRange * 100).rounded())) percent, above range \(Int((stats.aboveRange * 100).rounded())) percent"
            )
    }

    @ViewBuilder
    private func segment(_ fraction: Double, _ color: Color, _ width: CGFloat) -> some View {
        if fraction > 0 {
            color.frame(width: width * fraction)
        }
    }
}

struct SensorLifeCard: View {
    var pairing: SensorPairing?

    var body: some View {
        Card(title: "Sensor") {
            if let pairing {
                let remaining = max(0, pairing.expiryDate.timeIntervalSinceNow)
                let total = Double(pairing.maxAge) * 60
                HStack(alignment: .firstTextBaseline) {
                    Text(remaining / 86_400, format: .number.precision(.fractionLength(1)))
                        .font(.largeTitle.weight(.semibold).monospacedDigit())
                    Text("days left")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: total - remaining, total: total)
                    .tint(remaining < 86_400 ? .orange : .accentColor)
                Text("Ends \(pairing.expiryDate, format: .dateTime.weekday().hour().minute())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No sensor paired")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RecentReadingsCard: View {
    @Environment(AppSettings.self) private var settings
    var readings: [GlucoseReading]

    var body: some View {
        Card(title: "Recent readings") {
            if readings.isEmpty {
                Text("None yet").foregroundStyle(.secondary)
            }
            ForEach(readings, id: \.persistentModelID) { reading in
                HStack {
                    Text(reading.date, format: .dateTime.hour().minute())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.unit.format(mgdL: reading.mgdL))
                        .monospacedDigit()
                        .foregroundStyle(GlucoseLevel(mgdL: reading.mgdL, target: settings.target).color)
                }
                .font(.body)
                if reading.persistentModelID != readings.last?.persistentModelID {
                    Divider()
                }
            }
        }
    }
}
