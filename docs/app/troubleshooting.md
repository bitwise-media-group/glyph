---
description:
    Fixes for pairing errors, missing readings, signal loss, alerts that don't break through, and widgets or Live
    Activities that lag.
---

# Troubleshooting

Find the symptom, or the exact message Glyph shows.

## Pairing

These appear in the NFC sheet, and in red on the Sensor tab.

| Message                                                                                                | What to do                                                                                                                                           |
| ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| This iPhone can't read NFC tags.                                                                       | NFC isn't available on this device. Glyph needs an iPhone with NFC.                                                                                  |
| This sensor hasn't been started. Start it with the LibreLink app or a Libre reader, then scan it here. | Start it first: Glyph doesn't start sensors.                                                                                                         |
| This sensor has ended. Apply a new one.                                                                | It's past its wear time. [Replace it](../getting-started/sensor-life.md#replacing-a-sensor).                                                         |
| The sensor reports a failure and can't be used.                                                        | The sensor itself has failed. Replace it, and report it to Abbott.                                                                                   |
| The sensor's data didn't pass its integrity check. Hold the phone still and scan again.                | The scan was interrupted. Hold still, flat against the sensor, and retry.                                                                            |
| Lost contact with the sensor (…). Hold the phone still and scan again.                                 | The phone moved away mid-scan. Retry, and hold it there a moment longer.                                                                             |
| The sensor didn't enable Bluetooth. Scan again.                                                        | Scan again.                                                                                                                                          |
| FreeStyle Libre 1 sensors aren't supported: they have no Bluetooth.                                    | Glyph can't read this sensor.                                                                                                                        |
| The US Libre 2 isn't supported. Glyph works with the European Libre 2 and Libre 2 Plus.                | Glyph can't read this sensor. The Canadian Libre 2, second-generation Libre 2, Libre Sense, Libre Pro/H, US 14-day and Libre 3 get similar messages. |
| Scan cancelled.                                                                                        | You closed the sheet. Nothing changed.                                                                                                               |

## Signal lost

The sensor is paired, but no reading has arrived for five minutes. In order:

<div class="gl-steps" markdown>

1. **Bring the phone closer.** The sensor's Bluetooth reaches a few metres, less through a body or walls. Glyph picks
   the signal up again by itself.
2. **Check the Sensor tab's Bluetooth card.** If **Link** says _Bluetooth off_, turn on Bluetooth in Control Centre. If
   it says _Bluetooth not allowed_, allow it in <span class="gl-path">Settings ▸ Apps ▸ Glyph ▸ Bluetooth</span>.
3. **Check LibreLink.** If LibreLink's Bluetooth permission is on, LibreLink is taking the connection. Turn it off in
   <span class="gl-path">Settings ▸ Apps ▸ LibreLink</span>, then tap **Sensor ▸ Re-pair**.
4. **Re-pair.** Tap **Sensor ▸ Re-pair** and scan the sensor. That also back-fills the last eight hours.

</div>

## No readings after pairing

- **Sensor tab says _Warming up_?** The sensor's first hour gives no readings. Wait it out.
- **Stuck on _Connecting_?** Glyph is paired but hasn't heard from the sensor. Work through [Signal lost](#signal-lost):
  LibreLink holding the connection is the usual cause.

## Readings don't match a fingerstick

Sensors measure the fluid between cells, which lags blood by several minutes and drifts most in the first day. A
difference is normal when glucose is changing fast. If it's large and steady, trust the fingerstick, and remember that
Glyph is not a medical device.

## Alerts don't break through

- Allow notifications for Glyph: <span class="gl-path">Settings ▸ Notifications ▸ Glyph</span>.
- In the same place, turn on **Time Sensitive Notifications**.
- If you use a Focus, check that it doesn't silence time-sensitive notifications from Glyph.
- Check that the alert is on in [Settings ▸ Alerts](settings.md#alerts), and that you haven't snoozed it.

## Widgets are behind

Widgets refresh at most every five minutes, because iOS rations widget refreshes. That's by design: the
[Live Activity](widgets.md#live-activity) updates with every reading.

## The Live Activity doesn't appear

- Check **Settings ▸ Sharing ▸ Live Activity** in Glyph, and <span class="gl-path">Settings ▸ Apps ▸ Glyph ▸ Live
  Activities</span> in iOS.
- iOS only lets an app start a Live Activity while it's open. If streaming began in the background, open Glyph once.

## Save to Health is greyed out, or turns itself off

Greyed out means Health isn't available on this device. If it turns itself off, permission was refused: allow it in
<span class="gl-path">Health ▸ your profile ▸ Apps ▸ Glyph</span>, then turn the switch on again.
