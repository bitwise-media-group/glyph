---
description:
    Every setting in Glyph — units, target range, the six alerts and their snoozes, Apple Health, the Live Activity and
    the simulated sensor.
---

# Settings

Settings is a single form, in five sections. Changes take effect at once, everywhere: the widgets and the Live Activity
use the same unit and target range as the app.

<div class="gl-split" markdown>
<div markdown>

The mockup works: tap a switch to turn an alert on or off and see its rows open and close, and tap **Units** to swap
between mmol/L and mg/dL.

- [Display](#display): units and target range.
- [Alerts](#alerts): six alerts, their thresholds and snoozes.
- [Sharing](#sharing): Apple Health and the Live Activity.
- [Debug](#debug): the simulated sensor.
- [About](#about): the disclaimer and version.

</div>
<figure class="gl-figure"><div data-gl-mock="settings"></div><figcaption>
Try the switches and the Units row.
</figcaption></figure>
</div>

## Display

**Units**: **mmol/L** (the default) or **mg/dL**. Glyph stores everything in mg/dL and converts for display, so
switching is lossless and instant. Values step by 0.1 in mmol/L and by 1 in mg/dL.

**Target low** and **Target high** set your **target range**:

| Setting     | Default                 | Can be set from                 |
| ----------- | ----------------------- | ------------------------------- |
| Target low  | 3.9 mmol/L (70 mg/dL)   | 3.0–6.7 mmol/L (54–120 mg/dL)   |
| Target high | 10.0 mmol/L (180 mg/dL) | 6.7–13.9 mmol/L (120–250 mg/dL) |

The target range drives what's "in range" everywhere: the colour of every value, the green band on the charts, time in
range on Now and History, and the 14-day statistics. It doesn't change the alerts, which have their own thresholds.

## Alerts

Each alert has a switch. Turn one on and its threshold and **Snooze for** rows appear under it.

| Alert            | On by default | Fires when                              | Default threshold             | Range              | Snooze |
| ---------------- | :-----------: | --------------------------------------- | ----------------------------- | ------------------ | ------ |
| **Urgent low**   |      Yes      | the reading is below the threshold      | 3.1 mmol/L (55 mg/dL)         | 40–65 mg/dL        | 15 min |
| **Low**          |      Yes      | the reading is below the threshold      | 3.9 mmol/L (70 mg/dL)         | 54–100 mg/dL       | 30 min |
| **High**         |      Yes      | the reading is above the threshold      | 13.9 mmol/L (250 mg/dL)       | 140–400 mg/dL      | 1 h    |
| **Falling fast** |      No       | glucose is falling faster than the rate | 0.1 mmol/L (2 mg/dL) a minute | 1–4 mg/dL a minute | 30 min |
| **Rising fast**  |      No       | glucose is rising faster than the rate  | 0.1 mmol/L (2 mg/dL) a minute | 1–4 mg/dL a minute | 30 min |
| **No data**      |      Yes      | no reading has arrived for the time     | 20 min                        | 10–60 min, in 5s   | —      |

**Snooze for** can be 15 or 30 minutes, or 1 or 2 hours. It sets how long the **Snooze** button on that alert's
notification silences it.

[Alerts](alerts.md) explains when alerts repeat, how they interact, and how the no-data alert works without the app
running.

## Sharing

**Save to Health** (off by default) writes every reading to Apple Health as blood glucose. The first time you turn it
on, iOS asks for permission; if you don't allow it, the switch turns itself off again. The switch is greyed out on
devices without Health. See [Apple Health](health.md).

**Live Activity** (on by default) keeps your latest reading on the Lock Screen, in the Dynamic Island and on the iPhone
Duo's outer display. Turning it off ends the one that's showing. See
[Widgets & Live Activity](widgets.md#live-activity).

## Debug

**Simulated sensor** replaces Bluetooth with a synthetic sensor that sends real encrypted frames through the same
decoding pipeline as a real one. It's for trying Glyph without a sensor, and for development.

- Turning it on or off **removes the paired sensor**, then pairs the simulated one (or nothing).
- Simulated readings **never go to Health**.
- In the iOS Simulator this section is hidden: the simulated sensor is always on there.

## About

The reminder that Glyph is personal software and not a medical device, and the version you're running.

!!! warning "Confirm before you act"

    Don't make treatment decisions from Glyph alone. Confirm with a fingerstick when readings don't match how you feel.
