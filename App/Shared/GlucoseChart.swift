// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Charts
import GlyphCore
import SwiftUI

nonisolated struct GlucosePoint: Identifiable, Hashable, Sendable {
    var date: Date
    var mgdL: Double
    var id: Date { date }
}

/// The one glucose chart: the app's Now and History charts, the widget
/// sparkline and the Live Activity share it, differing by ``Style``.
///
/// Values are stored in mg/dL and plotted in the display unit. The target
/// band is a full-width rectangle, the alert thresholds are dashed rules,
/// and points are coloured by level.
struct GlucoseChart: View {
    enum Style {
        /// Axes, points, threshold rules, selection callout.
        case full
        /// Axes and smaller points; for panes and medium widgets.
        case compact
        /// Line only: widgets and the Live Activity.
        case sparkline
    }

    var points: [GlucosePoint]
    var unit: GlucoseUnit
    var target: TargetRange
    var lowThreshold: Double?
    var highThreshold: Double?
    /// The x range to show; defaults to the span of the points.
    var domain: ClosedRange<Date>?
    var style: Style = .full
    /// The scrubbed date, for `chartXSelection`.
    var selection: Binding<Date?>?

    var body: some View {
        Chart {
            RectangleMark(
                yStart: .value("Target low", unit.value(fromMgdL: target.lower)),
                yEnd: .value("Target high", unit.value(fromMgdL: target.upper))
            )
            .foregroundStyle(.green.opacity(style == .sparkline ? 0.15 : 0.12))

            if style == .full {
                if let lowThreshold {
                    RuleMark(y: .value("Low alert", unit.value(fromMgdL: lowThreshold)))
                        .foregroundStyle(.red.opacity(0.7))
                }
                if let highThreshold {
                    RuleMark(y: .value("High alert", unit.value(fromMgdL: highThreshold)))
                        .foregroundStyle(.yellow.opacity(0.8))
                }
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Glucose", unit.value(fromMgdL: clamped(point.mgdL)))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(style == .sparkline ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(0.6)))

                if showsPoints {
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Glucose", unit.value(fromMgdL: clamped(point.mgdL)))
                    )
                    .foregroundStyle(GlucoseLevel(mgdL: point.mgdL, target: target).color)
                }
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        callout(for: selected)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartYAxis(style == .sparkline ? .hidden : .automatic)
        .chartXAxis {
            if style != .sparkline {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
        }
        .chartLegend(.hidden)
        .modifier(SelectionModifier(selection: selection))
        .accessibilityChartDescriptor(
            GlucoseChartDescriptor(points: points, unit: unit, target: target))
    }

    /// Points are drawn for up to a day of five-minute data; beyond that
    /// (a scrollable fortnight) the line alone keeps scrolling smooth.
    private var showsPoints: Bool { style != .sparkline && points.count <= 800 }

    /// Plotted values stay inside the sensor's reporting range.
    private func clamped(_ mgdL: Double) -> Double {
        min(max(mgdL, ReportingRange.lowest), ReportingRange.highest)
    }

    private var xDomain: ClosedRange<Date> {
        if let domain { return domain }
        guard let first = points.map(\.date).min(), let last = points.map(\.date).max(), first < last else {
            let now = Date.now
            return now.addingTimeInterval(-3 * 3600)...now
        }
        return first...last
    }

    /// 40 to at least 250 mg/dL (or 300 when values go higher), so the
    /// band and thresholds stay in view.
    private var yDomain: ClosedRange<Double> {
        let highest = points.map(\.mgdL).max() ?? 0
        let top = highest > 250 ? max(300, min(highest + 20, ReportingRange.highest)) : 250
        return unit.value(fromMgdL: ReportingRange.lowest)...unit.value(fromMgdL: top)
    }

    private var selectedPoint: GlucosePoint? {
        guard style == .full, let date = selection?.wrappedValue else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func callout(for point: GlucosePoint) -> some View {
        VStack {
            Text(unit.format(mgdL: point.mgdL, withUnit: true))
                .font(.headline.monospacedDigit())
            Text(point.date, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: .capsule)
    }
}

private struct SelectionModifier: ViewModifier {
    var selection: Binding<Date?>?

    func body(content: Content) -> some View {
        if let selection {
            content.chartXSelection(value: selection)
        } else {
            content
        }
    }
}

/// The audio graph for VoiceOver: time on x, glucose on y.
nonisolated struct GlucoseChartDescriptor: AXChartDescriptorRepresentable {
    var points: [GlucosePoint]
    var unit: GlucoseUnit
    var target: TargetRange

    func makeChartDescriptor() -> AXChartDescriptor {
        let dates = points.map(\.date)
        let start = dates.min() ?? .now
        let end = max(dates.max() ?? .now, start.addingTimeInterval(60))
        let values = points.map { unit.value(fromMgdL: $0.mgdL) }
        let low = unit.value(fromMgdL: ReportingRange.lowest)
        let high = max(values.max() ?? 0, unit.value(fromMgdL: 250))

        let x = AXNumericDataAxisDescriptor(
            title: "Time", range: 0...end.timeIntervalSince(start), gridlinePositions: []
        ) { seconds in
            start.addingTimeInterval(seconds).formatted(date: .omitted, time: .shortened)
        }
        let y = AXNumericDataAxisDescriptor(
            title: "Glucose (\(unit.symbol))", range: low...high,
            gridlinePositions: [unit.value(fromMgdL: target.lower), unit.value(fromMgdL: target.upper)]
        ) { value in
            unit.format(mgdL: unit.mgdL(from: value), withUnit: true)
        }
        let series = AXDataSeriesDescriptor(
            name: "Glucose", isContinuous: true,
            dataPoints: points.map {
                AXDataPoint(x: $0.date.timeIntervalSince(start), y: unit.value(fromMgdL: $0.mgdL))
            })
        return AXChartDescriptor(
            title: "Glucose", summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}
