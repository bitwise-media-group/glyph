---
description:
    What you need before you pair a sensor with Glyph — an NFC iPhone on iOS 27, a European Libre 2 or Libre 2 Plus, and
    a way to start it.
---

# What you need

Glyph reads one kind of sensor, on one kind of phone, without help from anything else. Check this list before you apply
a new sensor, and the rest takes about two minutes.

!!! warning "Glyph is not a medical device"

    Glyph is personal software. It isn't approved as a continuous glucose monitor and isn't on the App Store. Don't
    make treatment decisions from it alone, and confirm with a fingerstick when a reading doesn't match how you feel.

## An iPhone

- **iOS 27.0 or later**, on an iPhone with NFC. Every iPhone that runs iOS 27 has it.
- **The iPhone Duo** gets the two-pane layout when it's unfolded. That uses iOS 27.1, and Glyph checks for it as it
  runs: on 27.0 you get two equal panes side by side instead. Every other iPhone uses the one-column layout with a tab
  bar. See [Tour of the app](../app/index.md#one-column-or-two).
- **Bluetooth on**, and the phone near you. The sensor's Bluetooth reaches a few metres.

## A sensor Glyph can read

Glyph reads the **European** FreeStyle Libre 2 and Libre 2 Plus. They talk the same Bluetooth protocol and differ only
in how long they last.

| Sensor                      | Product codes                       | Wears for                            |
| --------------------------- | ----------------------------------- | ------------------------------------ |
| FreeStyle Libre 2 (EU)      | `9D`, `C5`, and `7F` (generation 0) | 14 days, plus a 12-hour grace period |
| FreeStyle Libre 2 Plus (EU) | `C6`, and `7F` (later generations)  | 15 days, plus a 12-hour grace period |

You don't need to look up the code: Glyph reads it when you scan, and turns down any other sensor with a message that
says why. These **aren't supported**:

- FreeStyle Libre 1, which has no Bluetooth.
- The US FreeStyle Libre 14-day sensor, and FreeStyle Libre Pro/H.
- The US and Canadian Libre 2, and second-generation (US and Latin American) Libre 2 sensors.
- Libre Sense.
- FreeStyle Libre 3, which uses a different protocol.

## Something to start the sensor

**Glyph doesn't start sensors.** It refuses one that hasn't been started, so you need either:

- the **FreeStyle LibreLink** app, or
- a **FreeStyle Libre reader**.

You only use it once per sensor, to start it. After that, Glyph takes over.

!!! info "LibreLink and Glyph can't share Bluetooth"

    A sensor sends its readings to one app at a time. If you keep LibreLink installed, turn off its Bluetooth
    permission, or it takes the connection. [Pair a new sensor](pair-a-sensor.md) walks you through it.

## A way to install Glyph

Glyph isn't on the App Store, because a CGM can't be. You install it one of two ways:

- **TestFlight**, if whoever builds Glyph has invited you.
- **Xcode**, building it yourself. That needs a Mac with Xcode 27.2 or later and a paid Apple Developer account, because
  NFC tag reading, HealthKit and time-sensitive notifications all need one.

[Install Glyph](install.md) covers both.

## Next

<div class="gl-steps" markdown>

1. [Install Glyph](install.md) on your iPhone.
2. [Pair a new sensor](pair-a-sensor.md): start it, free up Bluetooth, scan it.
3. Learn [what happens next](sensor-life.md): warm-up, streaming, and the day it ends.

</div>
