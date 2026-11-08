// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import LibreKit
import SwiftUI

/// Pairing and the sensor's health.
///
/// Primary pane: the state, the scan / re-pair action and wear progress.
/// Secondary pane: identity, Bluetooth signal and debug capture.
struct SensorView: View {
    @Environment(SensorController.self) private var controller
    @Environment(AppSettings.self) private var settings
    @State private var confirmingRemoval = false

    var body: some View {
        NavigationStack {
            SectionPanes {
                statusCard
                if let pairing = controller.pairing {
                    WearCard(pairing: pairing)
                }
                Card(title: "Before you scan") {
                    Text(
                        "Only one app can receive a sensor's Bluetooth readings. In Settings ▸ Apps ▸ LibreLink, turn off Bluetooth, or LibreLink will take the connection."
                    )
                    .font(.callout)
                    Text(
                        "Glyph doesn't start sensors: start a new one with LibreLink or a Libre reader, then scan it here."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            } secondary: {
                if let pairing = controller.pairing {
                    DetailsCard(pairing: pairing, isSimulated: controller.isSimulated)
                }
                SignalCard()
                DebugCard()
            }
            .navigationTitle("Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Remove this sensor?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("Remove Sensor", role: .destructive) { controller.removeSensor() }
            } message: {
                Text("Glyph stops listening to it. Its readings stay in your history.")
            }
        }
    }

    private var statusCard: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Label(controller.phase.label, systemImage: phaseImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(phaseColor)
                Spacer()
                if controller.isSimulated {
                    Text("Simulated")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            if let error = controller.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Button {
                    Task { await controller.scan() }
                } label: {
                    Label(controller.pairing == nil ? "Scan Sensor" : "Re-pair", systemImage: "wave.3.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(controller.phase == .scanning)

                if controller.pairing != nil {
                    Button(role: .destructive) {
                        confirmingRemoval = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    private var phaseImage: String {
        switch controller.phase {
        case .streaming: "checkmark.circle.fill"
        case .warmingUp: "hourglass"
        case .connecting, .scanning: "antenna.radiowaves.left.and.right"
        case .signalLost: "antenna.radiowaves.left.and.right.slash"
        case .expired: "calendar.badge.exclamationmark"
        case .failed: "exclamationmark.triangle.fill"
        case .noSensor: "sensor.tag.radiowaves.forward"
        }
    }

    private var phaseColor: Color {
        switch controller.phase {
        case .streaming: .green
        case .warmingUp, .connecting, .scanning: .blue
        case .signalLost, .expired: .orange
        case .failed: .red
        case .noSensor: .secondary
        }
    }
}

private struct WearCard: View {
    var pairing: SensorPairing

    var body: some View {
        Card(title: "Wear") {
            let total = Double(pairing.maxAge) * 60
            let elapsed = min(total, max(0, Date.now.timeIntervalSince(pairing.startDate)))
            ProgressView(value: elapsed, total: total) {
                Text("Day \(Int(elapsed / 86_400) + 1) of \(Int((total / 86_400).rounded(.up)))")
            } currentValueLabel: {
                Text("Ends \(pairing.expiryDate, format: .dateTime.weekday(.wide).day().month().hour().minute())")
            }
            LabeledContent("Started", value: pairing.startDate, format: .dateTime.day().month().hour().minute())
        }
    }
}

private struct DetailsCard: View {
    var pairing: SensorPairing
    var isSimulated: Bool

    var body: some View {
        Card(title: "Sensor") {
            LabeledContent("Serial", value: pairing.serial)
            LabeledContent("Type", value: pairing.type.displayName)
            LabeledContent("Region", value: region)
            if let mac = pairing.mac {
                LabeledContent(
                    "Bluetooth address", value: mac.map { String(format: "%02X", $0) }.joined(separator: ":"))
            }
            LabeledContent("Advertises as", value: pairing.matcher.expectedName)
        }
        .textSelection(.enabled)
    }

    private var region: String {
        switch pairing.patchInfo.region {
        case .europe: "Europe"
        case .usa: "United States"
        case .australiaCanada: "Australia / Canada"
        case .restOfWorld: "Rest of world"
        case .unknown: "Unknown"
        }
    }
}

private struct SignalCard: View {
    @Environment(SensorController.self) private var controller

    var body: some View {
        Card(title: "Bluetooth") {
            LabeledContent("Link", value: controller.link.label)
            LabeledContent("Signal") {
                if let rssi = controller.rssi {
                    Label {
                        Text("\(rssi) dBm")
                    } icon: {
                        Image(systemName: "cellularbars", variableValue: strength(rssi))
                    }
                } else {
                    Text("–")
                }
            }
            LabeledContent("Last packet") {
                if let date = controller.lastFrameAt {
                    Text("\(Text(date, style: .relative)) ago")
                } else {
                    Text("–")
                }
            }
            LabeledContent("Frames received", value: controller.framesReceived, format: .number)
            LabeledContent("Frames dropped", value: controller.framesDropped, format: .number)
        }
    }

    /// −40 dBm (strong) to −100 dBm (weak) as 1…0.
    private func strength(_ rssi: Int) -> Double {
        min(1, max(0, Double(rssi + 100) / 60))
    }
}

private struct DebugCard: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Card(title: "Debug") {
            Toggle("Capture raw frames", isOn: $settings.captureRawFrames)
            Text("Appends each encrypted BLE frame and the sensor UID as hex, for building test fixtures.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if FileManager.default.fileExists(atPath: SensorController.captureURL.path()) {
                ShareLink(item: SensorController.captureURL) {
                    Label("Share Captured Frames", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}
