// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import SwiftData
import SwiftUI

/// The optional finger-prick calibration for the paired sensor: what it
/// does to readings, the finger-pricks behind it, and adding or clearing
/// them.
struct CalibrationCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ReadingPipeline.self) private var pipeline
    @Query private var bloodReadings: [BloodReading]
    @State private var isAdding = false
    @State private var confirmingReset = false
    private let serial: String

    init(serial: String) {
        self.serial = serial
        _bloodReadings = Query(
            filter: #Predicate<BloodReading> { $0.sensorSerial == serial }, sort: \.date, order: .reverse)
    }

    var body: some View {
        @Bindable var settings = settings
        Card(title: "Calibration") {
            if bloodReadings.isEmpty {
                Text(
                    "Readings use the sensor's factory calibration. If finger-pricks consistently disagree with it, add one to correct this sensor."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            } else {
                Toggle("Correct with finger-pricks", isOn: $settings.calibrationEnabled)
                    .onChange(of: settings.calibrationEnabled) { pipeline.calibrationChanged() }
                if let correction = UserCalibration.fit(bloodReadings.map(\.point)) {
                    effect(of: correction)
                        .foregroundStyle(settings.calibrationEnabled ? .primary : .secondary)
                }
                Divider()
                ForEach(bloodReadings.prefix(5)) { reading in
                    BloodReadingRow(reading: reading)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pipeline.deleteBloodReading(reading)
                            }
                        }
                }
                Text(
                    "New readings are corrected from now on; earlier ones keep their value. Touch and hold a finger-prick to delete it."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    isAdding = true
                } label: {
                    Label("Add Finger-Prick", systemImage: "drop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if !bloodReadings.isEmpty {
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            BloodReadingSheet(serial: serial)
        }
        .confirmationDialog("Reset calibration?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Delete Finger-Pricks", role: .destructive) { pipeline.resetCalibration(serial: serial) }
        } message: {
            Text("New readings go back to the sensor's factory calibration. Readings already stored keep their value.")
        }
    }

    /// The correction at the ends of the target range, which reads more
    /// plainly than a slope and offset.
    private func effect(of correction: LinearCorrection) -> some View {
        ForEach([settings.target.lower, settings.target.upper], id: \.self) { mgdL in
            LabeledContent("Sensor \(settings.unit.format(mgdL: mgdL))") {
                Text("shows \(settings.unit.format(mgdL: correction.apply(mgdL), withUnit: true))")
                    .monospacedDigit()
            }
        }
    }
}

private struct BloodReadingRow: View {
    @Environment(AppSettings.self) private var settings
    var reading: BloodReading

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(reading.date, format: .dateTime.weekday().hour().minute())
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Image(systemName: "drop.fill")) \(settings.unit.format(mgdL: reading.mgdL))")
                .foregroundStyle(.red)
            Text("sensor \(settings.unit.format(mgdL: reading.sensorMgdL))")
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }
}

/// Entering a finger-prick: the value, when it was taken, and what the
/// sensor read then.
struct BloodReadingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(ReadingPipeline.self) private var pipeline
    @State private var value: Double?
    @State private var date = Date.now
    @State private var error: CalibrationError?
    @FocusState private var isValueFocused: Bool
    var serial: String

    var body: some View {
        let sensor = pipeline.sensorValue(at: date, serial: serial)
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Blood glucose") {
                        HStack {
                            TextField("Value", value: $value, format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isValueFocused)
                            Text(settings.unit.symbol)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Taken", selection: $date, in: Date.now.addingTimeInterval(-12 * 3600)...Date.now)
                } footer: {
                    Text(
                        "Wash and dry your hands first. Calibrate when your glucose is steady, not after eating or exercise."
                    )
                }

                Section("Sensor at that time") {
                    if let sensor {
                        LabeledContent("Sensor", value: settings.unit.format(mgdL: sensor.mgdL, withUnit: true))
                        if let mgdL {
                            LabeledContent(
                                "Difference",
                                value: "\(settings.unit.formatDelta(mgdL: mgdL - sensor.mgdL)) \(settings.unit.symbol)")
                        }
                        if !UserCalibration.isSteady(rate: sensor.rate) {
                            Label(
                                "Glucose was changing quickly. The sensor lags blood by several minutes, so this finger-prick may make readings less accurate.",
                                systemImage: "exclamationmark.triangle"
                            )
                            .foregroundStyle(.orange)
                        }
                    } else {
                        Text("No sensor reading within 5 minutes of that time.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Finger-Prick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) { save() }
                        .disabled(mgdL == nil || sensor == nil)
                }
            }
        }
        .onAppear { isValueFocused = true }
    }

    private var mgdL: Double? { value.map(settings.unit.mgdL(from:)) }

    private func save() {
        guard let mgdL else { return }
        do {
            try pipeline.addBloodReading(mgdL: mgdL, at: date, serial: serial)
            dismiss()
        } catch {
            self.error = error
        }
    }
}
