---
description:
    Every mise task for Glyph, how the tests and fixtures work, formatting and lint, and the gate to run before a pull
    request.
---

# Build & test

Every task runs through `mise run <task>` (or `make <task>`, which forwards to it).

## Tasks

| Task                   | What it does                                                                                    |
| ---------------------- | ----------------------------------------------------------------------------------------------- |
| `mise run test`        | Swift Testing for LibreKit and GlyphCore, with coverage in `coverage/`.                         |
| `mise run build`       | A release `swift build` of the packages (what Linux CI builds).                                 |
| `mise run gen`         | Regenerates `Glyph.xcodeproj` from `project.yml` with XcodeGen.                                 |
| `mise run app-build`   | Builds the app and widgets for the iOS Simulator, unsigned, into `.build/xcode`.                |
| `mise run screenshots` | The screenshot UI tests: every scenario, on every screen it affects, in portrait and landscape. |
| `mise run fmt`         | Formats Swift (`swift format`) and Markdown (bun), and adds license headers.                    |
| `mise run lint`        | Checks all of that without changing anything, plus shell, workflow and Xcode Cloud script lint. |
| `mise run ci`          | What GitHub Actions runs: `lint`, `build`, `test`.                                              |
| `mise run pr`          | The full local gate: `fmt`, `lint`, `build`, `test`, `app-build`, then the commit step.         |
| `mise run serve`       | Previews this site at <http://localhost:8003>. See [This site](docs-site.md).                   |
| `mise run docs-build`  | Builds this site into `site/`.                                                                  |

Before every commit: `mise run fmt`, then `mise run lint`.

## Tests

The packages are tested with **Swift Testing**. `mise run test` writes `coverage/cobertura-coverage.xml` and
`coverage/junit.xml`, which CI uploads.

Two conventions keep the tests readable and the macros happy:

- Write `#expect` with **closures, not key paths**: `#expect(readings.allSatisfy { $0.isValid })`.
- Keep **mutating calls outside** the macro: call, then `#expect` the result.

### Fixtures

The protocol tests run against real bytes:

- `Tests/LibreKitTests/Fixtures.swift` holds **LibreTools' published examples** (MIT). The expected decrypted bytes and
  mg/dL values are the outputs of **GlucoseDirect's implementation** (MIT) for the same input.
- **New fixtures come from real sensors.** On a phone, turn on **Sensor ▸ Debug ▸ Capture raw frames**. Glyph appends
  `uid=… frame=…` lines to a log; share it with **Share Captured Frames**, and turn the lines into fixtures. See
  [Capturing frames](simulator-and-device.md#capturing-frames-from-a-real-sensor).

## The app build

`mise run app-build` is an unsigned simulator build, which is what most changes need. To run the app, open
`Glyph.xcodeproj` in Xcode and pick a simulator or a device; see [Simulator & device](simulator-and-device.md).

The app target defaults to **MainActor** isolation and the widget target to **nonisolated**, so code in `App/Shared` has
to compile under both. A build that passes for the app can still fail for the widgets.

## Screenshots

`mise run screenshots` runs the `GlyphUITests` suite. It drives every `GlucoseScenario` through the screens it affects,
in portrait and landscape, on the **iPhone Duo** and **iPhone 18 Pro** simulators, and writes the PNGs to
`.build/screenshots/<device>/`.

| Variable          | Default              | Example                                                               |
| ----------------- | -------------------- | --------------------------------------------------------------------- |
| `DESTINATIONS`    | both simulators      | `DESTINATIONS='id=<udid>'` for a connected phone; `;` between several |
| `SCREENSHOTS_DIR` | `.build/screenshots` | one directory per Duo posture                                         |

XCTest can rotate a device but can't fold one. Set the iPhone Duo's posture first, then run once per posture, each with
its own `SCREENSHOTS_DIR`.

## What CI checks

| Where          | Checks                                                                                  |
| -------------- | --------------------------------------------------------------------------------------- |
| GitHub Actions | `mise run lint`, `build` and `test` on Linux; `Glyph.xcodeproj` matches `project.yml`   |
| Xcode Cloud    | Builds and tests the app on pull requests; TestFlight on `main`; App Store on `v*` tags |
