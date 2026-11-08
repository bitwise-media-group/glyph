---
description: Set up a Mac to work on Glyph — Xcode, mise, the toolchain submodule, and signing with your own team.
---

# Local setup

## Prerequisites

- **macOS** with **Xcode 27.2 or later** (the iOS 27.2 SDK). The packages also build with the pinned swift.org
  toolchain, but the app needs Xcode.
- **[mise](https://mise.jdx.dev)**, which installs every other tool at a pinned version and runs the tasks.
- For running on a phone: a **paid Apple Developer account**. NFC tag reading, HealthKit, App Groups and time-sensitive
  notifications all need one. The simulator doesn't.

You don't need a sensor: the [simulated sensor](simulator-and-device.md#the-simulated-sensor) sends real encrypted
frames through the real decoding path.

## Clone and trust

```sh
git clone --recurse-submodules https://github.com/bitwise-media-group/glyph.git
cd glyph
mise trust
```

Already cloned without `--recurse-submodules`? Run `git submodule update --init`.

`.mise/` is the shared [toolchain](https://oss.bitwisemedia.uk/toolchain/), mounted as a submodule. It pins the tools
(bun, markdownlint, addlicense, shellcheck, actionlint, zizmor, uv and more) and supplies the common tasks: prose
formatting and lint, license headers, workflow lint, and this site's `docs-build` and `serve`. The repository's own
`mise.toml` adds:

| Tool                        | Pin    | Used for                                                     |
| --------------------------- | ------ | ------------------------------------------------------------ |
| Swift (swift.org toolchain) | 6.4.2  | `swift build`, `swift test`, `swift format` and `llvm-cov`   |
| XcodeGen                    | 2.46.0 | generating `Glyph.xcodeproj` from `project.yml` (macOS only) |

!!! danger "Don't run `mise lock` or a repo-wide `mise upgrade`"

    Both write into the `.mise/` submodule. Upgrade a single tool by editing its pin instead.

## Check it works

```sh
mise run test        # LibreKit and GlyphCore tests, with coverage
mise run app-build   # the app and widgets, for the iOS Simulator, unsigned
```

## Signing with your own team

The signing team, the bundle IDs and the App Group are set in **`project.yml`**, not in Xcode:

| Setting           | In `project.yml`                                 | Default                            |
| ----------------- | ------------------------------------------------ | ---------------------------------- |
| Team              | `DEVELOPMENT_TEAM`                               | BitWise Media Group's team         |
| App bundle ID     | the `Glyph` target's `PRODUCT_BUNDLE_IDENTIFIER` | `uk.co.bitwisemedia.glyph`         |
| Widgets bundle ID | the `GlyphWidgets` target's                      | `uk.co.bitwisemedia.glyph.widgets` |
| App Group         | the entitlements                                 | `group.uk.co.bitwisemedia.glyph`   |

Change them to ones your team owns, then regenerate:

```sh
mise run gen
open Glyph.xcodeproj
```

!!! warning "Edit `project.yml`, not the Xcode project"

    `Glyph.xcodeproj` is generated and committed. `mise run gen` overwrites anything changed in Xcode's project editor,
    and CI fails when the committed project doesn't match `project.yml`. Run `mise run gen` after editing `project.yml`,
    and after adding or removing app source files.

## Editors

Open `Glyph.xcodeproj` in Xcode for the app. For the packages alone, `Package.swift` opens in Xcode or any editor with
SourceKit-LSP. Format with `mise run fmt` rather than an editor's own formatter, so the result matches CI.

## Inside a sandbox

Coding agents and other sandboxes often can't trust `mise` or write SwiftPM's default scratch path. These work without
either:

```sh
xcrun swift test --scratch-path "$TMPDIR/glyph-build"
xcrun swift format format --in-place --recursive Package.swift Sources Tests App
xcodebuild … -derivedDataPath "$TMPDIR/glyph-dd" CODE_SIGNING_ALLOWED=NO
```
