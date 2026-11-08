// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import GlyphCore
import SwiftData
import SwiftUI
import UIKit

/// The object graph, built once per process. It must exist before launch
/// finishes, including when iOS relaunches Glyph in the background to
/// deliver a Bluetooth connection (state restoration), so the app delegate
/// creates it.
final class AppEnvironment {
    static let shared = AppEnvironment(scenario: LaunchOptions.scenario)

    let container: ModelContainer
    let settings: AppSettings
    let alerts: AlertNotifier
    let health: HealthKitWriter
    let liveActivity: LiveActivityController
    let pipeline: ReadingPipeline
    let controller: SensorController

    /// With a `scenario` (UI tests, screenshots) the store is in memory and
    /// alerts, the Live Activity and widget updates are off, so nothing real
    /// is touched and no prompt or banner covers the screen.
    init(scenario: GlucoseScenario? = nil) {
        let settings = AppSettings()
        let isLive = scenario == nil
        container = Persistence.makeContainer(inMemory: !isLive)
        self.settings = settings
        alerts = AlertNotifier(isEnabled: isLive, unit: { settings.unit })
        health = HealthKitWriter()
        liveActivity = LiveActivityController(isEnabled: isLive)
        pipeline = ReadingPipeline(
            context: container.mainContext, settings: settings, alerts: alerts, health: health,
            liveActivity: liveActivity, updatesWidgets: isLive)
        controller = SensorController(
            context: container.mainContext, pipeline: pipeline, settings: settings, scenario: scenario)
    }

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        controller.resume()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Sets the notification delegate and brings up CoreBluetooth with its
        // restoration identifier before launch completes.
        AppEnvironment.shared.start()
        return true
    }
}

@main
struct GlyphApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            AdaptiveRoot()
                .environment(environment.settings)
                .environment(environment.controller)
                .environment(environment.pipeline)
                .environment(\.healthKitWriter, environment.health)
                .environment(\.alertNotifier, environment.alerts)
                .environment(\.liveActivityController, environment.liveActivity)
                .task { await environment.alerts.requestAuthorization() }
        }
        .modelContainer(environment.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { environment.liveActivity.appBecameActive() }
        }
    }
}

extension EnvironmentValues {
    @Entry var healthKitWriter: HealthKitWriter? = nil
    @Entry var alertNotifier: AlertNotifier? = nil
    @Entry var liveActivityController: LiveActivityController? = nil
}
