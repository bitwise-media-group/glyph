// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import SwiftUI

/// Units, target range, alerts, Health and the rest. A plain Form: no panes
/// (an ArrangementView never goes inside a List).
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SensorController.self) private var controller
    @Environment(\.healthKitWriter) private var health
    @Environment(\.liveActivityController) private var liveActivity

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Units", selection: $settings.unit) {
                        ForEach(GlucoseUnit.allCases) { Text($0.symbol).tag($0) }
                    }
                    GlucoseStepper(title: "Target low", mgdL: $settings.target.lower, range: 54...120)
                    GlucoseStepper(title: "Target high", mgdL: $settings.target.upper, range: 120...250)
                }

                Section {
                    AlertRuleRow(kind: .urgentLow, rule: $settings.alerts.urgentLow, range: 40...65)
                    AlertRuleRow(kind: .low, rule: $settings.alerts.low, range: 54...100)
                    AlertRuleRow(kind: .high, rule: $settings.alerts.high, range: 140...400)
                    RateRuleRow(kind: .fallingFast, rule: $settings.alerts.fallingFast)
                    RateRuleRow(kind: .risingFast, rule: $settings.alerts.risingFast)
                    Toggle(isOn: $settings.alerts.signalLoss.isEnabled) {
                        Text("No data for \(Int(settings.alerts.signalLoss.threshold)) min")
                    }
                    if settings.alerts.signalLoss.isEnabled {
                        Stepper(
                            "After \(Int(settings.alerts.signalLoss.threshold)) min",
                            value: $settings.alerts.signalLoss.threshold, in: 10...60, step: 5)
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text(
                        "Alerts are time-sensitive and break through Focus. Snooze one from its notification. The no-data alert is scheduled ahead, so it fires even if Glyph isn't running."
                    )
                }

                Section {
                    Toggle("Save to Health", isOn: $settings.healthKitEnabled)
                        .disabled(health?.isAvailable != true)
                        .onChange(of: settings.healthKitEnabled) { _, enabled in
                            guard enabled, let health else { return }
                            Task {
                                if await !health.requestAuthorization() { settings.healthKitEnabled = false }
                            }
                        }
                    Toggle("Live Activity", isOn: $settings.liveActivityEnabled)
                        .onChange(of: settings.liveActivityEnabled) { _, enabled in
                            if !enabled { Task { await liveActivity?.end() } }
                        }
                } header: {
                    Text("Sharing")
                } footer: {
                    Text("Glyph writes blood glucose to Health and never reads from it.")
                }

                Section {
                    #if !targetEnvironment(simulator)
                        Toggle("Simulated sensor", isOn: $settings.useSimulatedSensor)
                            .onChange(of: settings.useSimulatedSensor) { _, _ in
                                controller.removeSensor()
                                controller.resume()
                            }
                    #endif
                } header: {
                    Text("Debug")
                } footer: {
                    Text("The simulated sensor sends synthetic readings through the full decoding pipeline.")
                }

                Section("About") {
                    Text(
                        "Glyph is personal software, not a medical device. Don't make treatment decisions from it alone; confirm with a fingerstick when readings don't match how you feel."
                    )
                    .font(.footnote)
                    LabeledContent(
                        "Version",
                        value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// A glucose value edited in the display unit, stored in mg/dL.
private struct GlucoseStepper: View {
    @Environment(AppSettings.self) private var settings
    var title: String
    @Binding var mgdL: Double
    var range: ClosedRange<Double>

    var body: some View {
        let unit = settings.unit
        Stepper(
            value: displayValue(unit),
            in: unit.value(fromMgdL: range.lowerBound)...unit.value(fromMgdL: range.upperBound), step: unit.step
        ) {
            LabeledContent(title, value: unit.format(mgdL: mgdL, withUnit: true))
        }
    }

    private func displayValue(_ unit: GlucoseUnit) -> Binding<Double> {
        Binding {
            unit.value(fromMgdL: mgdL)
        } set: { value in
            let scale = pow(10, Double(unit.fractionDigits))
            mgdL = unit.mgdL(from: (value * scale).rounded() / scale)
        }
    }
}

private struct AlertRuleRow: View {
    var kind: AlertKind
    @Binding var rule: AlertSettings.Rule
    var range: ClosedRange<Double>

    var body: some View {
        Toggle(kind.title, isOn: $rule.isEnabled)
        if rule.isEnabled {
            GlucoseStepper(title: kind == .high ? "Above" : "Below", mgdL: $rule.threshold, range: range)
            SnoozePicker(duration: $rule.snoozeDuration)
        }
    }
}

private struct RateRuleRow: View {
    @Environment(AppSettings.self) private var settings
    var kind: AlertKind
    @Binding var rule: AlertSettings.Rule

    var body: some View {
        Toggle(kind.title, isOn: $rule.isEnabled)
        if rule.isEnabled {
            let unit = settings.unit
            Stepper(value: $rule.threshold, in: 1...4, step: 0.5) {
                LabeledContent(
                    "Faster than",
                    value:
                        "\(unit.formatDelta(mgdL: rule.threshold).replacingOccurrences(of: "+", with: "")) \(unit.symbol)/min"
                )
            }
            SnoozePicker(duration: $rule.snoozeDuration)
        }
    }
}

private struct SnoozePicker: View {
    @Binding var duration: TimeInterval

    var body: some View {
        Picker("Snooze for", selection: $duration) {
            ForEach([15, 30, 60, 120], id: \.self) { minutes in
                Text(minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h").tag(TimeInterval(minutes * 60))
            }
        }
    }
}
