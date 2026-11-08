// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import SwiftUI

/// The four top-level sections, one tab each.
enum AppSection: String, CaseIterable, Identifiable {
    case now
    case history
    case sensor
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: "Now"
        case .history: "History"
        case .sensor: "Sensor"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .now: "drop.fill"
        case .history: "chart.xyaxis.line"
        case .sensor: "sensor.tag.radiowaves.forward.fill"
        case .settings: "gearshape.fill"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .now: NowView()
        case .history: HistoryView()
        case .sensor: SensorView()
        case .settings: SettingsView()
        }
    }
}
