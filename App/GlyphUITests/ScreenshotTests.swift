// Copyright 2026 BitWise Media Group Ltd
// SPDX-License-Identifier: MIT

import UniformTypeIdentifiers
import XCTest

/// Screenshots of every scenario on the screens it affects, in portrait and
/// landscape, saved as test attachments. `mise run screenshots` runs this and
/// exports them as PNGs, named for the window's shape (`portrait` or
/// `landscape`), which isn't always the device's orientation.
///
/// Each launch passes `-GlyphScenario`, so the app runs a fixed scenario
/// (`GlucoseScenario`) through the simulated sensor and the real decoding
/// pipeline, from an in-memory store with Bluetooth, alerts and the Live
/// Activity off. XCTest can rotate the device but can't fold it, so on the
/// iPhone Duo set the posture first (on the phone, or in Device Hub) and run
/// once per posture. Neither of the Duo's displays rotates in the simulator:
/// the outer one stays portrait and the inner one landscape, so each posture
/// gives one set.
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

    static let orientations: [UIDeviceOrientation] = [.portrait, .landscapeLeft]

    @MainActor
    func testScreenshots() throws {
        continueAfterFailure = true
        defer { XCUIDevice.shared.orientation = .portrait }
        var portraitSize: CGSize?
        for orientation in Self.orientations {
            XCUIDevice.shared.orientation = orientation
            for (scenario, sections) in Self.plan {
                let app = XCUIApplication()
                app.launchArguments = ["-GlyphScenario", scenario, "-GlyphSection", sections[0]]
                app.launch()
                let window = app.windows.firstMatch
                let windowSize = window.frame.size
                if orientation == .portrait {
                    portraitSize = portraitSize ?? windowSize
                } else if windowSize == portraitSize {
                    // This display doesn't rotate (either of the iPhone Duo's
                    // in the simulator): its shots would repeat portrait's.
                    app.terminate()
                    break
                }
                waitForData(in: app, scenario: scenario)
                for (index, section) in sections.enumerated() {
                    if index > 0 { open(section, in: app) }
                    pause(1.5)  // let charts and transitions settle
                    let size = window.frame.size
                    let shape = size.width > size.height ? "landscape" : "portrait"
                    // The window's screenshot, not the app's: on the unfolded
                    // iPhone Duo, app.screenshot() comes back black, since the
                    // main screen is the outer display, which is off.
                    attach(
                        window.screenshot(),
                        name: "\(shape)-\(Int(size.width))x\(Int(size.height))-\(scenario)-\(section)")
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

    /// Attaches the screenshot as a PNG with upright pixels. The iPhone Duo's
    /// inner panel is portrait, so its landscape screenshots come back as
    /// portrait pixels with an orientation tag, which tools that read the
    /// pixels (`design/app-store/build.py`, `rsvg-convert`) ignore.
    @MainActor
    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let image = screenshot.image
        let attachment: XCTAttachment
        if image.imageOrientation == .up {
            attachment = XCTAttachment(screenshot: screenshot)
        } else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = image.scale
            format.preferredRange = .standard
            let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(at: .zero)
            }
            attachment = XCTAttachment(
                data: upright.pngData() ?? screenshot.pngRepresentation, uniformTypeIdentifier: UTType.png.identifier)
        }
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }
}
