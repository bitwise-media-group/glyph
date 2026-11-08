---
description:
    Start a new Libre 2 or Libre 2 Plus sensor, free up its Bluetooth connection from LibreLink, and pair it with Glyph
    over NFC.
---

# Pair a new sensor

Pairing is a single NFC scan. Glyph reads the sensor's identity and the keys it needs, back-fills the readings the
sensor has stored, and from then on listens for a reading over Bluetooth about every minute.

Do these in order. Steps 1 and 2 happen outside Glyph.

<div class="gl-steps" markdown>

1. **Apply and start the sensor.** Apply it as the leaflet says, then start it with the **FreeStyle LibreLink** app or a
   **Libre reader**. Glyph doesn't start sensors, and turns down one that hasn't been started:

    > This sensor hasn't been started. Start it with the LibreLink app or a Libre reader, then scan it here.

2. **Turn off LibreLink's Bluetooth.** A sensor sends its readings over Bluetooth to one app at a time. If LibreLink is
   installed, open <span class="gl-path">Settings ▸ Apps ▸ LibreLink</span> and turn off **Bluetooth**. Skip this if you
   started the sensor with a reader and don't have LibreLink.

3. **Open Glyph's Sensor tab** and tap **Scan Sensor**. iOS slides up its scanning sheet.

4. **Hold the top of your iPhone to the sensor.** The NFC antenna is at the top edge. Keep it still, touching or nearly
   touching the sensor, until the sheet says **Sensor paired**. It takes a second or two.

5. **Wait for the first reading.** The Sensor tab moves from **Connecting** to **Streaming** once the first Bluetooth
   reading arrives. If the sensor is less than an hour old, it shows **Warming up** first, with the minutes left.

</div>

<figure class="gl-figure gl-reveal"><div data-gl-mock="scan"></div><figcaption>
The phone's NFC antenna is at its top edge. Hold that edge to the sensor until iOS says the sensor is paired.
</figcaption></figure>

## What pairing does

When the scan succeeds, Glyph has:

- **Identified the sensor**: its serial number, type (Libre 2 or Libre 2 Plus) and region, and turned it down if it's
  one Glyph can't read.
- **Checked it's running**: a sensor that hasn't been started, has ended, or reports a failure, is refused with a
  message that says which.
- **Read its stored readings**: the last 15 minutes minute by minute, and the last eight hours every 15 minutes, so your
  history doesn't start empty.
- **Turned on its Bluetooth** for Glyph, and learned the address to connect to.

Then it connects. The first reading usually arrives within a couple of minutes.

<figure class="gl-figure gl-reveal"><div data-gl-mock="sensor" data-phase="streaming"></div><figcaption>
Paired and streaming. The Sensor tab shows the state at the top, with Re-pair and Remove under it.
</figcaption></figure>

## If the scan doesn't work

The sheet closes with a message. The common ones:

| Message                                            | What to do                                                                             |
| -------------------------------------------------- | -------------------------------------------------------------------------------------- |
| The sensor's data didn't pass its integrity check. | Hold the phone still, flat against the sensor, and scan again.                         |
| Lost contact with the sensor.                      | The phone moved away mid-scan. Scan again and hold it there a moment longer.           |
| The sensor didn't enable Bluetooth.                | Scan again.                                                                            |
| This sensor has ended. Apply a new one.            | The sensor is past its wear time.                                                      |
| …sensors aren't supported.                         | It's a sensor Glyph can't read. See [What you need](index.md#a-sensor-glyph-can-read). |

[Troubleshooting](../app/troubleshooting.md) has the full list, and what to do when pairing works but no readings
arrive.

## Re-pairing

You don't need to re-pair for normal use: Glyph reconnects by itself after you restart the phone, after it goes out of
range, and when iOS relaunches it in the background. Re-pair with **Sensor ▸ Re-pair** when:

- you've moved to a **new iPhone**, or reinstalled Glyph;
- you **turned LibreLink's Bluetooth back on** at some point, and it has taken the connection; or
- the Sensor tab says **Signal lost** for a long time with the phone right next to you.

Re-pairing is the same scan. Readings Glyph already has stay as they are, and it doesn't duplicate any.

## Removing a sensor

**Sensor ▸ Remove** stops Glyph listening to the sensor. It asks first:

> Remove this sensor? Glyph stops listening to it. Its readings stay in your history.

You don't have to remove an ended sensor before scanning a new one: scanning the new one replaces it.
