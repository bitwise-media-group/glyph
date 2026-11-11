---
description:
    The Sensor tab — pair, re-pair and remove a sensor, follow its wear, calibrate it with finger-pricks, and check its
    identity and Bluetooth link.
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

## Calibration

Optional. Readings normally come from the sensor's **factory calibration**, with nothing for you to do. Some sensors
read consistently high or low all the same. If finger-pricks keep disagreeing with Glyph, you can correct that sensor
with them.

1. Take a finger-prick, ideally when your glucose is steady (a → arrow) and not just after eating, insulin or exercise.
   The sensor measures the fluid under the skin, which lags blood by several minutes.
2. Tap **Add Finger-Prick**, enter the value in your display unit, and set **Taken** if it wasn't just now. The sheet
   shows what the sensor read at that time and the difference. It warns you if glucose was changing quickly then.
3. **Save**. New readings are corrected from then on. Readings already stored, and those already in Health, keep their
   value.

How the correction is worked out:

- **One finger-prick**, or several at similar levels, shifts every reading by the average difference.
- **Finger-pricks at least 2 mmol/L (36 mg/dL) apart** fit a straight line through them, so a sensor that's further out
  at highs than at lows is corrected at both. The line's steepness is limited to between 0.7 and 1.5.
- Newer finger-pricks count for more, because a sensor's error drifts over its wear. A finger-prick counts half as much
  as one two days newer, and not at all after four days.

The card shows what the correction does at each end of your target range (**Sensor 3.9 shows 5.1 mmol/L**, say), and the
last five finger-pricks beside the sensor's value at the time. Touch and hold one to delete it.

**Correct with finger-pricks** turns the correction off without losing the finger-pricks. **Reset** deletes them. Each
sensor has its own: a new sensor starts on its factory calibration.

!!! warning "Calibration can make readings worse"

    A finger-prick taken while glucose is moving, with traces of food on your finger, or entered in the wrong unit
    teaches Glyph the wrong correction. A single finger-prick also shifts lows as much as highs. If corrected readings
    look wrong, reset the calibration. Glyph isn't a medical device. Check a finger-prick before treating a low or
    dosing insulin.

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

**Capture raw frames** appends every encrypted Bluetooth frame, and the sensor's NFC ID, to a log as hex, with the
sensor's factory calibration parameters and every finger-prick you enter. It's there to turn real sensors into test
fixtures for Glyph's developers, and to compare the factory values with finger-pricks. While a log exists, **Share
Captured Frames** sends it.

!!! warning "The log identifies your sensor"

    The captured frames, with the sensor ID, are enough to decrypt that sensor's readings. Share the log only with
    someone you'd share the readings with. See [Simulator & device](../development/simulator-and-device.md#capturing-frames-from-a-real-sensor).
