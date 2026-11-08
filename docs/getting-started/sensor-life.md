---
description:
    What happens after pairing — the warm-up hour, streaming about every minute, losing and regaining the signal, and
    replacing a sensor when it ends.
---

# A sensor's life

From the moment you start it to the day it ends, a sensor goes through the same few stages. Glyph shows which one it's
in at the top of the **Sensor** tab, and in a line under the reading on **Now** whenever something needs your attention.

<figure class="gl-figure gl-reveal"><div data-gl-mock="lifecycle"></div></figure>

## Warm-up

A new sensor needs its **first hour** to settle. During it, the sensor sends frames but no readings Glyph trusts, so
Glyph stores nothing and shows:

- **Sensor**: _Warming up, 38 min left_
- **Now**: _Sensor warming up: readings in 38 min._

The hour counts from when the sensor was started, not from when you scanned it. Scan a sensor that's already an hour old
and it goes straight to streaming.

<div class="gl-split" markdown>
<div markdown>

## Streaming

Once warm, the sensor sends a reading over Bluetooth **about every minute**. Each one goes through the same steps, in
order:

1. Glyph checks it isn't one it already has.
2. It stores it.
3. It checks your [alerts](../app/alerts.md).
4. It writes it to [Health](../app/health.md), if that's on.
5. It updates the [Live Activity](../app/widgets.md#live-activity).
6. It refreshes your [widgets](../app/widgets.md), at most every five minutes.

Glyph keeps receiving while it's in the background or the phone is locked. If iOS stops it, Bluetooth relaunches it for
the next reading.

</div>
<figure class="gl-figure"><div data-gl-mock="sensor" data-phase="warming"></div><figcaption>
Paired, in its first hour.
</figcaption></figure>
</div>

## Signal lost

If no reading arrives for **five minutes**, the Sensor tab says **Signal lost**, the reading on Now turns grey and is
struck through, and Now says _Signal lost. Keep your phone near the sensor._ Usually the phone was simply too far away,
and Glyph picks the signal up again on its own when you come back into range.

Gaps fill themselves in. Every reading the sensor sends also carries a few from the last 15 minutes and three from the
last 45 minutes (on a 15-minute grid), so a short gap closes with the first reading after it. For a longer one, scan the
sensor again (**Sensor ▸ Re-pair**): a scan reads back the last eight hours.

If it lasts **20 minutes** (you can change this), the [no-data alert](../app/alerts.md#no-sensor-data) fires, even if
Glyph isn't running.

## The end

A Libre 2 lasts **14 days** and a Libre 2 Plus **15 days**, each with a **12-hour grace period** after that. The
**Sensor** card on Now counts down the days left and turns orange in the last 24 hours. When it ends, the Sensor tab
says **Sensor ended**, and Now says _Sensor ended. Scan a new one._

### Replacing a sensor

<div class="gl-steps" markdown>

1. Apply the new sensor, and start it with LibreLink or a reader, as before.
2. Make sure LibreLink's Bluetooth is still **off**.
3. In Glyph, tap **Sensor ▸ Scan Sensor** and scan the **new** sensor.

</div>

The new sensor replaces the old one. Your history carries on across both, so History's 14 days can span two sensors.

!!! note "Warm-up again"

    Every new sensor starts with its warm-up hour, so expect an hour without readings when you change sensors. Some
    people apply the new one an hour before the old one ends, and start it then, to close the gap.

## Every state, at a glance

| Sensor tab says          | Means                                               | Readings? |
| ------------------------ | --------------------------------------------------- | :-------: |
| No sensor                | Nothing paired yet, or the sensor was removed.      |    No     |
| Scanning                 | An NFC scan is in progress.                         |    No     |
| Connecting               | Paired; waiting for the first Bluetooth frame.      |    No     |
| Warming up, _N_ min left | In the sensor's first hour.                         |    No     |
| Streaming                | Receiving readings about every minute.              |    Yes    |
| Signal lost              | No frame for five minutes. Glyph keeps trying.      |  Paused   |
| Sensor ended             | Past its wear time. Replace it.                     |    No     |
| Pairing failed           | The scan went wrong; the message under it says why. |    No     |
