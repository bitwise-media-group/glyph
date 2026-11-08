// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import ActivityKit
import GlyphCore
import SwiftUI
import WidgetKit

/// The real-time surface: Lock Screen, Dynamic Island, StandBy and the
/// iPhone Duo's outer display when folded. Updated by the app on every
/// reading; once the stale date passes the value is dimmed and struck
/// through.
struct GlucoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseActivityAttributes.self) { context in
            LockScreenView(state: context.state, isStale: context.isStale)
                .padding()
                .activityBackgroundTint(.black.opacity(0.4))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    value(
                        state, isStale: context.isStale, font: .system(.largeTitle, design: .rounded).weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        if let delta = state.deltaMgdL {
                            Text("\(state.unit.formatDelta(mgdL: delta)) \(state.unit.symbol)")
                        }
                        Text(state.date, style: .relative)
                            .foregroundStyle(context.isStale ? .orange : .secondary)
                    }
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GlucoseChart(points: points(state), unit: state.unit, target: state.target, style: .sparkline)
                        .aspectRatio(5, contentMode: .fit)
                }
            } compactLeading: {
                Text(state.mgdL.map { state.unit.format(mgdL: $0) } ?? "–")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(color(state))
                    .strikethrough(context.isStale)
            } compactTrailing: {
                Image(systemName: state.trend.systemImage)
                    .foregroundStyle(color(state))
            } minimal: {
                Text(state.mgdL.map { state.unit.format(mgdL: $0) } ?? "–")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(color(state))
            }
        }
    }

    private func value(_ state: GlucoseActivityAttributes.ContentState, isStale: Bool, font: Font) -> some View {
        GlucoseValueLabel(
            mgdL: state.mgdL, trend: state.trend, unit: state.unit, target: state.target, isStale: isStale, font: font)
    }

    private func color(_ state: GlucoseActivityAttributes.ContentState) -> Color {
        state.mgdL.map { GlucoseLevel(mgdL: $0, target: state.target).color } ?? .secondary
    }

    private func points(_ state: GlucoseActivityAttributes.ContentState) -> [GlucosePoint] {
        state.recent.map { GlucosePoint(date: $0.date, mgdL: $0.mgdL) }
    }
}

private struct LockScreenView: View {
    let state: GlucoseActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                GlucoseValueLabel(
                    mgdL: state.mgdL, trend: state.trend, unit: state.unit, target: state.target, isStale: isStale,
                    font: .system(.largeTitle, design: .rounded).weight(.semibold))
                HStack {
                    if let delta = state.deltaMgdL {
                        Text("\(state.unit.formatDelta(mgdL: delta)) \(state.unit.symbol)")
                    }
                    Text(state.date, style: .relative)
                        .foregroundStyle(isStale ? .orange : .secondary)
                }
                .font(.footnote)
            }
            GlucoseChart(
                points: state.recent.map { GlucosePoint(date: $0.date, mgdL: $0.mgdL) }, unit: state.unit,
                target: state.target, style: .sparkline)
        }
    }
}
