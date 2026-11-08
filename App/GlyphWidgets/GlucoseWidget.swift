// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import LibreKit
import SwiftUI
import WidgetKit

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    var isStale: Bool { snapshot.isStale(at: date) }
    var points: [GlucosePoint] { snapshot.recent.map { GlucosePoint(date: $0.date, mgdL: $0.mgdL) } }
}

/// Reads the snapshot the app writes to the App Group. The app reloads the
/// timelines at most every five minutes (the widget budget); each timeline
/// carries a second entry at the moment the reading goes stale, so the
/// widget dims without needing another reload.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseEntry {
        GlucoseEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (GlucoseEntry) -> Void) {
        let snapshot = SnapshotStore.read()
        completion(
            GlucoseEntry(date: .now, snapshot: context.isPreview && snapshot.latest == nil ? .placeholder : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<GlucoseEntry>) -> Void) {
        let now = Date.now
        let snapshot = SnapshotStore.read()
        var entries = [GlucoseEntry(date: now, snapshot: snapshot)]
        if let latest = snapshot.latest {
            let staleAt = latest.date.addingTimeInterval(WidgetSnapshot.staleAfter + 1)
            if staleAt > now { entries.append(GlucoseEntry(date: staleAt, snapshot: snapshot)) }
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct GlucoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "glucose", provider: SnapshotProvider()) { entry in
            GlucoseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Glucose")
        .description("Your latest reading and trend.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct GlucoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlucoseEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .minimumScaleFactor(0.6)
                    Image(systemName: snapshot.trend.systemImage)
                        .font(.caption.weight(.bold))
                }
                .opacity(entry.isStale ? 0.5 : 1)
            }
            .widgetAccentable()
        case .accessoryRectangular:
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    valueLabel(font: .system(.title2, design: .rounded).weight(.semibold))
                    timeLabel
                }
                GlucoseChart(points: entry.points, unit: snapshot.unit, target: snapshot.target, style: .sparkline)
            }
        case .systemMedium:
            HStack {
                VStack(alignment: .leading) {
                    valueLabel(font: .system(.largeTitle, design: .rounded).weight(.semibold))
                    if let delta = snapshot.deltaMgdL {
                        Text("\(snapshot.unit.formatDelta(mgdL: delta)) \(snapshot.unit.symbol)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    timeLabel
                }
                GlucoseChart(points: entry.points, unit: snapshot.unit, target: snapshot.target, style: .sparkline)
            }
        default:
            VStack(alignment: .leading) {
                valueLabel(font: .system(.largeTitle, design: .rounded).weight(.semibold))
                timeLabel
                GlucoseChart(points: entry.points, unit: snapshot.unit, target: snapshot.target, style: .sparkline)
            }
        }
    }

    private var value: String {
        snapshot.latest.map { snapshot.unit.format(mgdL: $0.mgdL) } ?? "–"
    }

    private func valueLabel(font: Font) -> some View {
        GlucoseValueLabel(
            mgdL: snapshot.latest?.mgdL, trend: snapshot.trend, unit: snapshot.unit, target: snapshot.target,
            isStale: entry.isStale, font: font)
    }

    @ViewBuilder
    private var timeLabel: some View {
        if let latest = snapshot.latest {
            Text(latest.date, style: .relative)
                .font(.caption)
                .foregroundStyle(entry.isStale ? .orange : .secondary)
        } else {
            Text("Open Glyph to pair")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var inlineText: String {
        guard let latest = snapshot.latest else { return "Glyph: no reading" }
        let minutes = Int(entry.date.timeIntervalSince(latest.date) / 60)
        return "\(value) \(snapshot.trend.symbol) · \(minutes) min"
    }
}

extension WidgetSnapshot {
    /// What the widget gallery shows.
    static var placeholder: WidgetSnapshot {
        let now = Date.now
        let points = (0..<36).map { step in
            Point(date: now.addingTimeInterval(Double(step - 35) * 300), mgdL: 120 + 30 * sin(Double(step) / 6))
        }
        return WidgetSnapshot(
            latest: points.last, recent: points, trend: .risingSlightly, deltaMgdL: 4, unit: .mmolL, target: .standard,
            sensorExpiry: now.addingTimeInterval(5 * 86_400), updatedAt: now)
    }
}
