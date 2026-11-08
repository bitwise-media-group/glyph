// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import ActivityKit
import Foundation
import os

/// Starts, updates and ends the glucose Live Activity.
///
/// The app is awake for every BLE frame, so it updates the activity locally
/// on each reading; no push server. Each update's stale date is five minutes
/// out, so a missed update shows as stale on the Lock Screen and the Duo's
/// outer display. iOS only lets an activity start while the app is in the
/// foreground: if streaming begins in the background the start is retried
/// when the app next becomes active.
final class LiveActivityController {
    static let staleAfter: TimeInterval = 5 * 60

    private var pendingStart: (GlucoseActivityAttributes, GlucoseActivityAttributes.ContentState)?
    private let log = Logger(subsystem: "uk.co.bitwisemedia.glyph", category: "live-activity")
    /// Off in UI tests.
    private let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    // The running activity is looked up from `Activity.activities` each time
    // rather than stored: Activity isn't Sendable, and a fresh local can be
    // handed to ActivityKit's async calls where a stored property can't.

    func update(_ state: GlucoseActivityAttributes.ContentState, serial: String, expiry: Date?) async {
        guard isEnabled else { return }
        let content = ActivityContent(state: state, staleDate: state.date.addingTimeInterval(Self.staleAfter))
        for running in Activity<GlucoseActivityAttributes>.activities
        where running.attributes.sensorSerial == serial && running.activityState == .active {
            await running.update(content)
            return
        }
        await end()
        start(GlucoseActivityAttributes(sensorSerial: serial, expiry: expiry), content: content)
    }

    /// Retries a start that iOS refused while the app was in the background.
    func appBecameActive() {
        guard isEnabled, Activity<GlucoseActivityAttributes>.activities.isEmpty, let (attributes, state) = pendingStart
        else {
            return
        }
        start(
            attributes,
            content: ActivityContent(state: state, staleDate: state.date.addingTimeInterval(Self.staleAfter)))
    }

    func end() async {
        pendingStart = nil
        for activity in Activity<GlucoseActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func start(
        _ attributes: GlucoseActivityAttributes, content: ActivityContent<GlucoseActivityAttributes.ContentState>
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            pendingStart = nil
        } catch {
            pendingStart = (attributes, content.state)
            log.info("live activity start deferred: \(error.localizedDescription, privacy: .public)")
        }
    }
}
