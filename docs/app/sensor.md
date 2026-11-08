---
description:
    The Sensor tab — pair, re-pair and remove a sensor, follow its wear, and check its identity and Bluetooth link.
---

# Sensor

The Sensor tab is where you pair a sensor and check on it. Its first pane is about the sensor's **state**; its second is
the detail you'll want when something's wrong.

## State

The card at the top says what the sensor is doing, in colour, with the action that fits:

=== "Streaming"

    <figure class="gl-figure"><div data-gl-mock="sensor" data-phase="streaming"></div></figure>

    All's well: a reading is arriving about every minute. **Re-pair** scans the sensor again; **Remove** stops Glyph
    listening to it.

=== "Warming up"

    <figure class="gl-figure"><div data-gl-mock="sensor" data-phase="warming"></div></figure>

    Paired, in the sensor's first hour. No readings until it's done; the minutes left count down.

=== "No sensor"

    <figure class="gl-figure"><div data-gl-mock="sensor" data-phase="none"></div></figure>

    Nothing paired. **Scan Sensor** starts the NFC scan: hold the top of the phone to the sensor.

=== "Signal lost"

    <figure class="gl-figure"><div data-gl-mock="sensor" data-phase="lost"></div></figure>

    Paired, but nothing for five minutes. Glyph keeps trying by itself; bring the phone closer. See
    [Troubleshooting](troubleshooting.md#signal-lost).

The full list of states is in [A sensor's life](../getting-started/sensor-life.md#every-state-at-a-glance). If a scan
fails, its message appears in red under the state, and clears on the next success.

The buttons:

- **Scan Sensor** (nothing paired) or **Re-pair** (a sensor is paired) starts an NFC scan. See
  [Pair a new sensor](../getting-started/pair-a-sensor.md).
- **Remove** asks first, then stops Glyph listening to the sensor. Its readings stay in your history.

## Wear

How far through its life the sensor is: **Day 7 of 15**, a bar, the date and time it **ends**, and when it **started**.
The end includes the 12-hour grace period.

## Before you scan

A standing reminder of the two things that trip people up: turn off LibreLink's Bluetooth, and start new sensors with
LibreLink or a reader first.

## Sensor details

The sensor's identity, all selectable so you can copy it:

| Row               | Example                                      |
| ----------------- | -------------------------------------------- |
| Serial            | The serial printed on the sensor's packaging |
| Type              | FreeStyle Libre 2 Plus                       |
| Region            | Europe                                       |
| Bluetooth address | `A1:B2:C3:D4:E5:F6`                          |
| Advertises as     | The Bluetooth name Glyph looks for           |

## Bluetooth

The live link to the sensor. Useful when readings stop.

| Row                 | What it tells you                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| **Link**            | Idle, Bluetooth off, Bluetooth not allowed, Searching, Waiting for sensor, Connected or Disconnected. |
| **Signal**          | Received signal strength in dBm, with bars: about −40 is strong, −100 is the edge of range.           |
| **Last packet**     | How long since the last frame arrived.                                                                |
| **Frames received** | Frames since Glyph started.                                                                           |
| **Frames dropped**  | Frames that failed their checks. A few are normal; many mean interference.                            |

**Bluetooth off** and **Bluetooth not allowed** are the two you can fix at once: turn on Bluetooth in Control Centre, or
allow it in <span class="gl-path">Settings ▸ Apps ▸ Glyph ▸ Bluetooth</span>.

## Debug

**Capture raw frames** appends every encrypted Bluetooth frame, and the sensor's NFC ID, to a log as hex. It's there to
turn real sensors into test fixtures for Glyph's developers. While a log exists, **Share Captured Frames** sends it.

!!! warning "The log identifies your sensor"

    The captured frames, with the sensor ID, are enough to decrypt that sensor's readings. Share the log only with
    someone you'd share the readings with. See [Simulator & device](../development/simulator-and-device.md#capturing-frames-from-a-real-sensor).
