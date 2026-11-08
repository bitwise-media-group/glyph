---
description: Working on Glyph — how the repository is laid out, the tools it uses, and where to start.
---

# Development

Glyph is two Swift packages and an iOS app. The packages hold everything that isn't UI or hardware, are Foundation-only,
and build and test on Linux. The app wires them to NFC, Bluetooth, SwiftData, HealthKit, notifications and WidgetKit.

<div class="grid cards" markdown>

- :material-laptop: **[Local setup](setup.md)**

    Xcode, mise and the toolchain submodule; signing with your own team.

- :material-hammer-wrench: **[Build & test](build-and-test.md)**

    Every `mise run` task, the tests and fixtures, formatting and lint, and what CI checks.

- :material-cellphone: **[Simulator & device](simulator-and-device.md)**

    The simulated sensor, launch arguments and scenarios, the iPhone Duo simulator, and real sensors.

- :material-sitemap: **[How it works](architecture.md)**

    From an NFC scan to a number on the Lock Screen: the protocol, the pipeline and the layout.

- :material-scale-balance: **[House rules](rules.md)**

    Licensing, the protocol's sharp edges, and the layout and concurrency rules the code keeps to.

- :material-book-open-variant: **[This site](docs-site.md)**

    How these docs are built, previewed and published, and how the app mockups work.

</div>

## The repository

```text
Package.swift            two libraries: LibreKit and GlyphCore
Sources/LibreKit         the Libre 2 protocol: sensor types, CRC, crypto, FRAM and BLE parsing,
                         factory calibration, trend, frame decoding
Sources/GlyphCore        app logic: units, statistics and AGP, dedupe, the alert engine,
                         the widget snapshot, test scenarios
Tests/                   Swift Testing suites for both libraries
App/Glyph                the SwiftUI app: sensor layer (NFC, CoreBluetooth, simulator), SwiftData
                         store, reading pipeline, alerts, HealthKit, Live Activity, layout, screens
App/GlyphWidgets         the widgets and the Live Activity
App/Shared               compiled into both: the chart, the snapshot, the activity attributes
App/GlyphUITests         the screenshot suite
project.yml              the XcodeGen spec; Glyph.xcodeproj is generated from it and committed
design/app-icon          the Icon Composer icon and the script that draws its layers
docs/                    this site (and the factory-calibration spec, which isn't published)
ci_scripts/              Xcode Cloud's hooks
.mise/                   the shared toolchain, a git submodule
```

## Continuous integration

CI is split in two:

- **GitHub Actions** runs everything that doesn't need Xcode: lint, the package build and tests on Linux, and a check
  that `Glyph.xcodeproj` still matches `project.yml`.
- **Xcode Cloud** builds and tests the app on pull requests, sends merges to `main` to TestFlight, and builds `v*` tags
  for the App Store. Its workflows live in App Store Connect, not in the repository; only its hooks in `ci_scripts/` do.
  Xcode Cloud sets the build number itself.

Releases are cut by release-please from [Conventional Commits](https://www.conventionalcommits.org/), which also bumps
the app's marketing version in `App/Config/Version.xcconfig`.
