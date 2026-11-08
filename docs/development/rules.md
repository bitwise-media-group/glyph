---
description:
    The rules Glyph's code keeps to — licensing and provenance, the protocol's sharp edges, layout, sizing, OS
    availability and concurrency.
---

# House rules

These are the constraints a change to Glyph has to respect. Most exist because getting them wrong is either a licensing
problem or a bug that only shows on a real sensor or a real fold.

## Licensing and provenance

- **MIT, independent implementation.** Never copy or translate **xdripswift** code: it's GPL-3.0. Use it for protocol
  facts only (UUIDs, command bytes, offsets, timings).
- **Port from the MIT projects** listed in `NOTICE` (LibreTools, GlucoseDirect, DiaBLE), and credit them there and in
  the file's header.
- **Factory calibration is isolated.** `Sources/LibreKit/Calibration/FactoryCalibration.swift` is written from
  [`docs/factory-calibration.md`](https://github.com/bitwise-media-group/glyph/blob/main/docs/factory-calibration.md).
  Change the spec first, then the code. It stays the only implementation of the conversion, behind `GlucoseConverter`.

!!! warning "Factory calibration needs a legal opinion"

    The conversion first appeared publicly in GPL-3.0 code, and the MIT projects that carry it credit that source, so
    its MIT status is doubtful. `NOTICE` explains. Get a legal opinion before the repository is made public, and be
    ready to replace the file (with fingerstick-based calibration, for example). The spec is kept out of this site
    for the same reason.

## The protocol

- **One Bluetooth client per sensor.** LibreLink's Bluetooth permission must be off, or it takes the connection.
- **Glyph never activates sensors.** It refuses one that hasn't been started.
- **The unlock counter is saved before the BLE unlock write.** The sensor rejects a reused count.
- **Readings are keyed by (serial, sensor age)**, the sensor's own minute counter. That key drives dedupe, back-fill and
  the HealthKit sync identifier.

## Layout

- **Switch on `horizontalSizeClass` only**, never on the device, orientation or `UIScreen`.
- **`ArrangementView` sits at a section's `NavigationStack` root**, never inside a `List` or `ScrollView`.
- **No custom navigation chrome.** Use `TabView`, `NavigationStack` and `.toolbar`: on the Duo in landscape the system
  builds the vertical bar itself, as Apple's apps do. An earlier custom rail duplicated it and fought it.
- **Panes use the system's split.** `ArrangementView` with `.split` and its defaults: no custom ratio or clearance.
  `contentMargins(for: .container)` is about the container's edges, not the fold.
- **No fixed sizes.** Use system defaults (spacing, padding, `GroupBox` cards, Swift Charts' strokes and symbols), text
  styles, proportions (`expandingHeight(aspectRatio:)`, aspect ratios, capsules) and multiples of system metrics, so new
  screens and densities keep working. Debug-only overlays are exempt.

## Availability

**iOS 27.0 is the floor.** The iPhone Duo APIs (`ArrangementView`, reserved regions, `splitArrangementAxis`,
`onHingeChange`, `toolbarVerticalEdge`) are iOS 27.1, so they go behind `#available(iOS 27.1, *)` with a sensible
fallback. The deployment target is 27.0, so the build enforces it.

## Concurrency

- The **app** target defaults to **MainActor** isolation; the **widget** target to **nonisolated**, because WidgetKit
  calls providers off the main actor. Code in `App/Shared` must compile under both.
- **Don't send non-Sendable framework objects** (`NFCISO15693Tag`, `Activity`) into their async APIs. Use the
  completion-handler forms, or look up a fresh local, as `LiveActivityController` does with `Activity.activities`.

## Commits

- Run `mise run fmt`, then `mise run lint`, before committing.
- Write [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, …). release-please
  derives versions and the changelog from them.
- After editing `project.yml` or adding or removing app files, run `mise run gen` and commit the regenerated project.
