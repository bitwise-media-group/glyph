// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import Charts
import GlyphCore
import SwiftUI

/// The ambulatory glucose profile: every day folded onto one, with the
/// median line over the 25–75 % and 5–95 % percentile bands.
struct AGPChart: View {
    @Environment(AppSettings.self) private var settings
    var readings: [(date: Date, mgdL: Double)]

    /// A fixed day the slots are plotted on, so the x axis reads as times.
    private static let referenceDay = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

    var body: some View {
        let buckets = AGPProfile.compute(readings)
        if buckets.isEmpty {
            Text("Not enough readings yet").foregroundStyle(.secondary)
        } else {
            Chart {
                RectangleMark(
                    yStart: .value("Target low", unit.value(fromMgdL: settings.target.lower)),
                    yEnd: .value("Target high", unit.value(fromMgdL: settings.target.upper))
                )
                .foregroundStyle(.green.opacity(0.1))

                ForEach(buckets) { bucket in
                    AreaMark(
                        x: .value("Time", time(bucket)),
                        yStart: .value("5th percentile", unit.value(fromMgdL: bucket.p5)),
                        yEnd: .value("95th percentile", unit.value(fromMgdL: bucket.p95)),
                        series: .value("Band", "5–95 %")
                    )
                    .foregroundStyle(.blue.opacity(0.15))
                    .interpolationMethod(.monotone)

                    AreaMark(
                        x: .value("Time", time(bucket)),
                        yStart: .value("25th percentile", unit.value(fromMgdL: bucket.p25)),
                        yEnd: .value("75th percentile", unit.value(fromMgdL: bucket.p75)),
                        series: .value("Band", "25–75 %")
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    .interpolationMethod(.monotone)

                    LineMark(x: .value("Time", time(bucket)), y: .value("Median", unit.value(fromMgdL: bucket.median)))
                        .foregroundStyle(.blue)
                        .interpolationMethod(.monotone)
                }
            }
            .chartXScale(domain: Self.referenceDay...Self.referenceDay.addingTimeInterval(86_400))
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYScale(domain: unit.value(fromMgdL: 40)...unit.value(fromMgdL: 300))
            .accessibilityLabel("Daily glucose pattern: median and percentile bands by time of day")
        }
    }

    private var unit: GlucoseUnit { settings.unit }

    private func time(_ bucket: AGPBucket) -> Date {
        Self.referenceDay.addingTimeInterval(Double(bucket.minuteOfDay) * 60)
    }
}
