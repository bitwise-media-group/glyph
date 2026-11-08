// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import XCTest

/// Screenshots of every scenario on the screens it affects, in portrait and
/// landscape, saved as test attachments. `mise run screenshots` runs this and
/// exports them as PNGs.
///
/// Each launch passes `-GlyphScenario`, so the app runs a fixed scenario
/// (`GlucoseScenario`) through the simulated sensor and the real decoding
/// pipeline, from an in-memory store with Bluetooth, alerts and the Live
/// Activity off. XCTest can rotate the device but can't fold it, so on the
/// iPhone Duo set the posture first (on the phone, or in Device Hub) and run
/// once per posture.
final class ScreenshotTests: XCTestCase {
    /// The screens each scenario is captured on.
    static let plan: [(scenario: String, sections: [String])] = [
        ("inRange", ["now", "history", "sensor", "settings"]),
        ("high", ["now"]),
        ("low", ["now"]),
        ("urgentLow", ["now"]),
        ("risingFast", ["now"]),
        ("fallingFast", ["now"]),
        ("warmingUp", ["now", "sensor"]),
        ("signalLost", ["now", "sensor"]),
        ("expired", ["now", "sensor"]),
        ("noSensor", ["now", "sensor"]),
    ]

    static let tabTitles = ["now": "Now", "history": "History", "sensor": "Sensor", "settings": "Settings"]

    static let orientations: [(name: String, orientation: UIDeviceOrientation)] = [
        ("portrait", .portrait), ("landscape", .landscapeLeft),
    ]

    @MainActor
    func testScreenshots() throws {
        continueAfterFailure = true
        defer { XCUIDevice.shared.orientation = .portrait }
        var portraitSize: CGSize?
        for (orientationName, orientation) in Self.orientations {
            XCUIDevice.shared.orientation = orientation
            for (scenario, sections) in Self.plan {
                let app = XCUIApplication()
                app.launchArguments = ["-GlyphScenario", scenario, "-GlyphSection", sections[0]]
                app.launch()
                let windowSize = app.windows.firstMatch.frame.size
                if orientation == .portrait {
                    portraitSize = portraitSize ?? windowSize
                } else if windowSize == portraitSize {
                    // This screen doesn't rotate (the folded iPhone Duo's
                    // outer display): its shots would repeat portrait's.
                    app.terminate()
                    break
                }
                waitForData(in: app, scenario: scenario)
                for (index, section) in sections.enumerated() {
                    if index > 0 { open(section, in: app) }
                    pause(1.5)  // let charts and transitions settle
                    let size = app.windows.firstMatch.frame.size
                    attach(
                        app.screenshot(),
                        name: "\(orientationName)-\(Int(size.width))x\(Int(size.height))-\(scenario)-\(section)")
                }
                app.terminate()
            }
        }
    }

    /// Waits for the first reading, for scenarios that have one.
    @MainActor
    private func waitForData(in app: XCUIApplication, scenario: String) {
        let value = app.descendants(matching: .any)["glucose-value"]
        guard ["warmingUp", "expired", "noSensor"].contains(scenario) == false else {
            _ = value.waitForExistence(timeout: 15)
            return
        }
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", "No reading"), object: value)
        if XCTWaiter.wait(for: [ready], timeout: 30) != .completed {
            XCTFail("\(scenario): no reading appeared")
        }
    }

    @MainActor
    private func open(_ section: String, in app: XCUIApplication) {
        guard let title = Self.tabTitles[section] else { return }
        let tab = app.tabBars.buttons[title]
        let button = tab.exists ? tab : app.buttons[title].firstMatch
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            XCTFail("no tab named \(title)")
        }
    }

    @MainActor
    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }
}
