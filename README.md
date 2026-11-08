# Glyph

Glyph is a small iPhone app that does one thing. It reads a **FreeStyle Libre 2** or **Libre 2 Plus** sensor (the
European ones) directly, and shows the readings well. You pair over NFC, and then a new reading arrives over Bluetooth
about every minute. No LibreLink, reader or cloud is involved.

It is designed for the **iPhone Duo** first:

- **Folded**, or in narrow Split View, it uses the standard tab bar.
- **Unfolded**, it splits each screen into two panes along the fold, and in landscape the system moves the tabs, back
  button and toolbar into a vertical bar beside the status icons. The panes sit side by side when the fold is vertical,
  and stack when it is horizontal.

> Glyph is personal software, **not a medical device**. It can't be distributed on the App Store as a CGM. Install it on
> your own devices from Xcode or TestFlight. Don't make treatment decisions from it alone.

The [documentation site](https://oss.bitwisemedia.uk/glyph/) covers pairing a sensor, every screen and setting, and
local development. Its source is in `docs/`.

## What it does

- **Now:** the current value in mmol/L or mg/dL, with a trend arrow, the change over 5 minutes and the time since the
  reading. Below that are a three-hour chart, time in range today, the sensor's days left and the last 15 readings.
- **History:** 14 days in a scrollable chart. You can pick a 3, 6, 12 or 24-hour window and scrub for exact values. It
  also shows 14-day statistics (average, GMI, time in, below and above range, CV) and an ambulatory glucose profile.
- **Alerts:** urgent low, low, high, and falling or rising fast, each with its own snooze. A no-data alert fires even
  when Glyph isn't running. Alerts are time-sensitive, and critical once Apple grants that entitlement.
- **Health:** writes blood glucose to the Health app. It never reads from Health, and it never creates duplicates.
- **Widgets and Live Activity:**
  - Home Screen and Lock Screen widgets.
  - A Live Activity that updates with every reading on the Lock Screen, in the Dynamic Island and on the Duo's outer
    display.

## Requirements

- An iPhone running **iOS 27.0 or later** with NFC. The iPhone Duo layout uses APIs from iOS 27.1, which Glyph checks
  for at run time.
- **Xcode 27.2 or later.**
- A **paid Apple Developer account.** NFC tag reading, HealthKit, App Groups and time-sensitive notifications all need
  one.
- A Libre 2 or Libre 2 Plus sensor from the EU, product codes `9D`, `C5`, `C6` or `7F`. Glyph turns down any other
  sensor and says why, including the US Libre 2, Libre 3 and Libre 1.

### Before you pair

1. **Start the sensor with LibreLink or a Libre reader.** Glyph doesn't activate sensors.
2. **Turn off LibreLink's Bluetooth permission** in Settings ▸ Apps ▸ LibreLink. A sensor talks to only one app at a
   time over Bluetooth.
3. In Glyph, go to Sensor ▸ **Scan Sensor** and hold the top of the iPhone to the sensor.

## Building

The project uses [mise](https://mise.jdx.dev) for tools and tasks. The shared toolchain is a git submodule at `.mise/`.

```sh
git submodule update --init
mise trust
mise run test        # LibreKit + GlyphCore tests, with coverage
mise run gen         # regenerate Glyph.xcodeproj from project.yml
mise run app-build   # build the app and widgets for the iOS Simulator
mise run screenshots # screenshot every glucose scenario on the iPhone Duo and iPhone 18 Pro simulators
mise run serve       # preview the documentation site at http://localhost:8003
open Glyph.xcodeproj # then run on a device
```

The signing team, the bundle ID (`uk.co.bitwisemedia.glyph`) and the App Group (`group.uk.co.bitwisemedia.glyph`) are
set in `project.yml`. Change them there rather than in Xcode, because `mise run gen` regenerates the project.

In the simulator, and on a device with Settings ▸ Debug ▸ Simulated sensor turned on, Glyph pairs a **simulated
sensor**. It sends real encrypted frames through the same decoding path a real sensor's frames take.

## How it fits together

```text
Sources/LibreKit    the Libre 2 protocol: Foundation only, tested on Linux
Sources/GlyphCore   units, statistics, dedupe, alert engine, widget snapshot
App/Glyph           SwiftUI app: sensor layer (NFC, CoreBluetooth, simulator),
                    SwiftData store, reading pipeline, alerts, HealthKit,
                    Live Activity, adaptive layout, screens
App/GlyphWidgets    widgets and the Live Activity
App/Shared          code shared by both (chart, snapshot, activity attributes)
```

Every new reading goes through one pipeline, in this order:

1. Dedupe it against stored readings, using the sensor's serial and its own minute counter.
2. Store it.
3. Evaluate alerts.
4. Write it to Health.
5. Update the Live Activity.
6. Refresh the widgets, at most every 5 minutes.

## Licence

MIT; see [LICENSE](LICENSE). The crypto and protocol code is ported from MIT-licensed projects, credited in
[NOTICE](NOTICE). The **factory calibration** is kept in a file of its own and written from
[a specification](docs/factory-calibration.md). Its provenance is unresolved, so it needs a legal opinion before this
repository is made public. `NOTICE` explains why.
