# glyph

An iPhone app that reads a FreeStyle Libre 2 (EU) or Libre 2 Plus (EU) sensor directly: NFC to pair, then BLE about once
a minute. It shows the readings in SwiftUI and Swift Charts, and it is built iPhone Duo-first: two panes on the fold at
regular width, with navigation left to the system's tab bar (which the Duo turns into a vertical bar beside the status
icons in landscape). It supports iOS 27.0 and later; the Duo APIs need 27.1 and are behind `#available` checks. It is
personal software, not a medical device.

## Layout

- `Package.swift`: two Foundation-only libraries, so both build and test on Linux CI.
  - `LibreKit`: the protocol (sensor types, CRC, crypto, FRAM/BLE parsing, factory calibration, trend, frame decoding).
  - `GlyphCore`: app logic (units, statistics/AGP, dedupe, the alert engine, the widget snapshot).
- `App/`: the iOS app (`Glyph`) and the widget extension (`GlyphWidgets`). `App/Shared` is compiled into both.
- `design/app-icon/`: the app icon. `AppIcon.icon` is an Icon Composer document that Xcode compiles into the layered
  icons, and `generate.py` writes its SVG layers. Edit the icon there, not in the asset catalog.
- CI is split in two:
  - **GitHub Actions** (`.github/workflows/ci.yaml`) runs the gates that need no Xcode: lint, package build and tests on
    Linux, and the XcodeGen drift check.
  - **Xcode Cloud** builds and tests the app on pull requests, sends merges to `main` to TestFlight, and builds `v*`
    tags for the App Store. Its workflows live in App Store Connect, managed through the API, not in the repo.
- `ci_scripts/`: Xcode Cloud's hooks (they must sit beside the project). Xcode Cloud sets the build number itself.
- `project.yml`: the XcodeGen spec. `Glyph.xcodeproj` is generated from it and committed. Run `mise run gen` after
  editing `project.yml` or adding or removing app files. CI fails if the two drift.

## Rules

- **MIT, independent implementation.** Never copy or translate xdripswift (GPL-3.0) code. Use it only for protocol facts
  (UUIDs, command bytes, offsets, timings). Port from the MIT projects listed in `NOTICE` (LibreTools, GlucoseDirect,
  DiaBLE) and credit them there and in the file header.
- **Factory calibration is isolated.** `Sources/LibreKit/Calibration/FactoryCalibration.swift` is written from
  `docs/factory-calibration.md`. Change the spec first, then the code. Keep it the only implementation of the
  conversion, behind `GlucoseConverter`. It needs a legal opinion before the repo goes public (see `NOTICE`).
- **One BLE client per sensor.** LibreLink's Bluetooth permission must be off, or it takes the connection. Glyph never
  activates sensors: it refuses a sensor that hasn't been started.
- **The unlock counter is saved before the BLE unlock write.** The sensor rejects a reused count.
- **Readings are keyed by (serial, sensor age)**, the sensor's own minute counter. That key drives dedupe, back-fill and
  the HealthKit sync identifier.
- **Layout switches on `horizontalSizeClass` only**, never on the device, orientation or `UIScreen`. `ArrangementView`
  sits at a section's NavigationStack root, and never inside a List or ScrollView.
- **No custom navigation chrome.** Use `TabView`, `NavigationStack` and `.toolbar`: on the Duo in landscape the system
  stacks the back button, toolbar items and tabs in a vertical bar in the trailing status column
  (`toolbarVerticalEdge`), as Apple's apps do. An earlier custom rail duplicated and fought it.
- **Panes use the system's split.** `ArrangementView` with `.split` and its defaults: partially open, the system keeps
  the panes off the crease itself; flat, content may cross the crease (decided on the device). No custom ratio or
  clearance. `contentMargins(for: .container)` is about the container's edges, not the fold.
- **No fixed sizes.** Use system defaults (spacing, padding, `GroupBox` cards, Swift Charts strokes and symbols), text
  styles, proportions (`expandingHeight(aspectRatio:)`, aspect ratios, capsules) and multiples of system metrics, so new
  screen sizes and densities keep working. Debug-only overlays are exempt.
- **iOS 27.0 is the floor.** Put 27.1 APIs (`ArrangementView`, reserved regions, `splitArrangementAxis`,
  `onHingeChange`, `toolbarVerticalEdge`) behind `#available(iOS 27.1, *)` with a sensible fallback. The build enforces
  it, since the deployment target is 27.0.
- **Concurrency.** The app target defaults to MainActor isolation and the widget target to nonisolated (WidgetKit calls
  providers off the main actor). Code in `App/Shared` must compile under both. Don't send non-Sendable framework objects
  (`NFCISO15693Tag`, `Activity`) into their async APIs. Use the completion-handler forms, or a fresh local.

## Commands

- `mise run fmt`, then `mise run lint`, before committing. Never run `mise lock` or a repo-wide `mise upgrade`: they
  write into the `.mise/` submodule. Run `mise trust` once per clone.
- `mise run test`: Swift Testing with coverage, for LibreKit and GlyphCore.
- `mise run app-build`: unsigned simulator build of the app and widgets. Needs Xcode 27.2 or later.
- `mise run screenshots`: the `GlyphUITests` screenshot suite. It captures every `GlucoseScenario` on the screens it
  affects, in portrait and landscape, on the iPhone Duo and iPhone 18 Pro simulators. The PNGs go to
  `.build/screenshots/<device>/`. Set `DESTINATIONS='id=<udid>'` to run on the phone. XCTest can rotate a device but
  can't fold it, so set the Duo's posture first and run once per posture.

Inside the Claude Code sandbox, `mise` may be untrusted and SwiftPM's default scratch path is blocked. These work:

- `xcrun swift test --scratch-path "$TMPDIR/glyph-build"`
- `xcrun swift format format --in-place --recursive Package.swift Sources Tests App`
- `xcodebuild … -derivedDataPath "$TMPDIR/glyph-dd" CODE_SIGNING_ALLOWED=NO`
- `cd "$TMPDIR" && mise exec xcodegen@2.46.0 -- xcodegen generate --spec "$OLDPWD/project.yml" --project "$OLDPWD"`

Folding the simulator needs Device Hub's UI: neither `simctl` nor `devicectl` can change the posture. On the physical
iPhone Duo (`dm-iphone-duo`), signed builds work from the sandbox:

- `xcodebuild … -destination 'id=00008160-001C20DC2EC0000A' -derivedDataPath "$TMPDIR/glyph-dd-device"`
- `xcrun devicectl device install app --device <udid> <path to Glyph.app>`
- `xcrun devicectl device process launch --terminate-existing --device <udid> uk.co.bitwisemedia.glyph`
- `xcrun devicectl device info displays --device <udid>` reports which screen is active (folded or not) and its
  rotation.
- `xcrun devicectl device capture screenshot --device <udid> --display-unique-id <id> --destination <png>`

Debug launch arguments (`LaunchOptions`; release builds ignore them):

- `-GlyphScenario <name>` runs a fixed `GlucoseScenario` through the simulated sensor and the real decoding pipeline. It
  uses an in-memory store, and Bluetooth, alerts, the Live Activity and widget updates are all off, so it's safe on the
  user's own phone.
- `-GlyphSection now|history|sensor|settings` opens on that section.
- `-GlyphShowReservedRegions` draws the fold (red) and occlusions (blue), and prints the hinge state.

## Tests and fixtures

- The fixtures in `Tests/LibreKitTests/Fixtures.swift` are LibreTools' published examples (MIT). The expected decrypted
  bytes and mg/dL values are outputs of GlucoseDirect's implementation (MIT) for the same input.
- New fixtures come from real sensors. Turn on Sensor ▸ Debug ▸ Capture raw frames, which writes `uid=… frame=…` lines,
  then share the log.
- Write `#expect` with closures, not key paths (`allSatisfy { $0.isValid }`). Keep mutating calls outside the macro.
