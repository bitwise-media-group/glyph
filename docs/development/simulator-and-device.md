---
description:
    Run Glyph in the simulator or on a phone — the simulated sensor, debug launch arguments and scenarios, folding the
    iPhone Duo, and capturing real sensor frames.
---

# Simulator & device

## The simulated sensor

Glyph has a sensor of its own for when there isn't a real one. It isn't a stub: it builds **real encrypted Bluetooth
frames** and sends them through the same decrypting, CRC-checking and decoding path a real sensor's frames take, so the
whole app runs as it would on your arm.

- **In the iOS Simulator** it's always on. Tap **Sensor ▸ Scan Sensor** to pair it.
- **On a phone**, turn on **Settings ▸ Debug ▸ Simulated sensor**. That removes the paired sensor and pairs the
  simulated one. Its readings never go to Health.

## Launch arguments

Debug builds read these launch arguments. Release builds ignore them. Set them in Xcode under **Product ▸ Scheme ▸ Edit
Scheme ▸ Run ▸ Arguments**, or pass them to `simctl launch` or `devicectl … process launch`.

| Argument                    | Effect                                                                               |
| --------------------------- | ------------------------------------------------------------------------------------ |
| `-GlyphScenario <name>`     | Runs a fixed scenario through the simulated sensor and the real decoding pipeline.   |
| `-GlyphSection <section>`   | Opens on `now`, `history`, `sensor` or `settings`.                                   |
| `-GlyphShowReservedRegions` | Draws the fold (red) and occlusions (blue) over the app, and prints the hinge state. |

### Scenarios

A scenario uses a **throwaway in-memory store**, with Bluetooth, alerts, the Live Activity and widget updates all off.
It's safe to run on your own phone: your sensor, readings and widgets are untouched.

| Scenario      | Where it ends up                                                                |
| ------------- | ------------------------------------------------------------------------------- |
| `inRange`     | About 6.2 mmol/L (112 mg/dL), steady                                            |
| `high`        | About 14.5 mmol/L (262 mg/dL), creeping up                                      |
| `low`         | About 3.6 mmol/L (64 mg/dL), creeping down                                      |
| `urgentLow`   | About 2.7 mmol/L (49 mg/dL), falling slightly                                   |
| `risingFast`  | About 9.3 mmol/L (168 mg/dL), rising quickly                                    |
| `fallingFast` | About 5.3 mmol/L (96 mg/dL), falling                                            |
| `signalLost`  | Readings that stopped at about 7.1 mmol/L (128 mg/dL): signal lost, stale value |
| `warmingUp`   | A sensor 25 minutes old: warming up                                             |
| `expired`     | A sensor past its 15 days: sensor ended                                         |
| `noSensor`    | Nothing paired                                                                  |

```sh
xcrun simctl launch booted uk.co.bitwisemedia.glyph -GlyphScenario urgentLow -GlyphSection now
```

## The iPhone Duo simulator

The iPhone Duo simulator boots and runs from `simctl` like any other. **Folding and unfolding needs Device Hub's UI**:
neither `simctl` nor `devicectl` can change the posture, and powering the screens with `simctl io … screenConfig`
doesn't change it either.

`-GlyphShowReservedRegions` is the quickest way to see what the layout is avoiding: the fold is drawn in red, and
anything occluding the screen in blue.

## On a phone

Running from Xcode is the usual way. From the command line, a signed build installs and launches with `devicectl`:

```sh
xcodebuild build -project Glyph.xcodeproj -scheme Glyph \
  -destination 'id=<udid>' -derivedDataPath .build/xcode-device
xcrun devicectl device install app --device <udid> <path to Glyph.app>
xcrun devicectl device process launch --terminate-existing --device <udid> uk.co.bitwisemedia.glyph
```

On an iPhone Duo, `devicectl` can also tell you which screen is active and take screenshots of either:

```sh
xcrun devicectl device info displays --device <udid>   # which screen is on (folded or not), and its rotation
xcrun devicectl device capture screenshot --device <udid> --display-unique-id <id> --destination shot.png
```

## Capturing frames from a real sensor

New protocol fixtures come from real sensors.

<div class="gl-steps" markdown>

1. On the phone, turn on **Sensor ▸ Debug ▸ Capture raw frames**.
2. Let it stream for a while. Each frame is appended to `glyph-frames.log` in the app's Documents, as a `uid=… frame=…`
   line of hex. The first frame from a sensor in each session is preceded by a `sensor … calibration=i1,…,i6` line with
   its factory parameters (only NFC delivers those, so the frames alone can't be converted to mg/dL), and each
   finger-prick you enter adds a `blood … mgdL=… sensorMgdL=…` line. Together they're enough to replay the sensor and
   compare its factory values with blood.
3. Tap **Share Captured Frames** to send the log, then turn it off again.

</div>

!!! warning "Treat the log like the readings"

    The sensor's ID and its encrypted frames are all it takes to decrypt that sensor's readings. Share captures only
    with people you'd share the readings with, and don't commit a capture that isn't yours to share.
