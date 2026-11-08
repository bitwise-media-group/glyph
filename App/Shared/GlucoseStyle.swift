// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import LibreKit
import SwiftUI
import UIKit

extension GlucoseLevel {
    /// Colour for a value at this level. Red and orange for lows, green in
    /// range, yellow for highs, matching common CGM conventions.
    var color: Color {
        switch self {
        case .urgentLow: .red
        case .low: .orange
        case .inRange: .green
        case .high: .yellow
        }
    }
}

/// The current value with its trend arrow, used by the app, widgets and
/// Live Activity alike.
struct GlucoseValueLabel: View {
    var mgdL: Double?
    var trend: TrendArrow
    var unit: GlucoseUnit
    var target: TargetRange
    var isStale: Bool = false
    /// `nil` uses twice the system's large-title size at the current
    /// Dynamic Type setting, rounded.
    var font: Font?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(mgdL.map { unit.format(mgdL: $0) } ?? "–")
                .font(resolvedFont)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isStale ? AnyShapeStyle(.secondary) : AnyShapeStyle(level?.color ?? .primary))
                .strikethrough(isStale, color: .secondary)
            if mgdL != nil {
                Image(systemName: trend.systemImage)
                    .font(resolvedFont.weight(.bold))
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("glucose-value")
    }

    private var resolvedFont: Font {
        font ?? .system(size: heroSize, weight: .semibold, design: .rounded)
    }

    private var heroSize: CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFont.preferredFont(forTextStyle: .largeTitle, compatibleWith: traits).pointSize * 2
    }

    private var level: GlucoseLevel? {
        mgdL.map { GlucoseLevel(mgdL: $0, target: target) }
    }

    private var accessibilityText: Text {
        guard let mgdL else { return Text("No reading") }
        let stale = isStale ? ", out of date" : ""
        return Text("\(unit.format(mgdL: mgdL, withUnit: true)), \(trend.accessibilityDescription)\(stale)")
    }
}
