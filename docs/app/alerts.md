---
description:
    How Glyph's six alerts work — when they fire and repeat, how they break through Focus, snoozing, and the no-data
    alert that fires even when Glyph isn't running.
---

# Alerts

Glyph checks every new reading against your alerts. When one fires you get a notification, with the value and a
**Snooze** button, that breaks through Focus.

<div class="gl-split" markdown>
<div markdown>

## The six alerts

| Alert              | Default          | Urgency        |
| ------------------ | ---------------- | -------------- |
| **Urgent low**     | under 3.1 mmol/L | Urgent         |
| **Low**            | under 3.9 mmol/L | Time-sensitive |
| **High**           | over 13.9 mmol/L | Time-sensitive |
| **Falling fast**   | off              | Time-sensitive |
| **Rising fast**    | off              | Time-sensitive |
| **No sensor data** | after 20 min     | Urgent         |

Set them up in [Settings ▸ Alerts](settings.md#alerts). The notification's title is the alert; its body is the reading,
and the rate of change when Glyph knows it.

</div>
<figure class="gl-figure"><div data-gl-mock="lock-alert"></div><figcaption>
A low alert arrives as a time-sensitive notification. Snooze is one press away.
</figcaption></figure>
</div>

## When an alert fires, and fires again

- An alert fires **as soon as its condition becomes true**: the first reading below your low threshold, say.
- **While the condition stays true**, it repeats on its own schedule: urgent low every **5 minutes**, low every **15
  minutes**, high every **hour**, and the rate alerts every **30 minutes**.
- When the condition **clears**, the alert resets, so the next time it's true you hear about it straight away.

### Alerts don't pile up

- **Urgent low replaces low.** Below the urgent threshold, you get the urgent alert, not both.
- **A level alert replaces the rate alert going the same way.** Already low and falling fast? You get the low alert:
  "falling fast" adds nothing. Likewise high and rising fast.

## Snoozing

Press and hold the notification and tap **Snooze**. That alert is silenced for its **Snooze for** time (15 minutes to 2
hours; you set it per alert), even if the condition stays true. Other alerts aren't affected: snoozing a high doesn't
silence a low.

Snoozes and repeat timers are saved, so a relaunch neither re-alerts you nor forgets a snooze.

## Breaking through Focus

Every Glyph alert is **time-sensitive**, so it reaches you through Focus and Scheduled Summary. Make sure it's allowed:
<span class="gl-path">Settings ▸ Notifications ▸ Glyph ▸ Time Sensitive Notifications</span>.

**Urgent low** and **no sensor data** are the urgent ones. Once Apple grants Glyph the critical-alerts entitlement, they
will also play through silent mode and Do Not Disturb, if you allow critical alerts for Glyph.

## No sensor data

The other alerts need a reading to fire, so they can't tell you when readings stop. The no-data alert can.

Each reading **schedules a notification for 20 minutes later** (or whatever you set) and cancels the previous one. As
long as readings keep coming, it never goes off. When they stop, for whatever reason (the phone out of range, the sensor
failed, iOS stopped Glyph), iOS delivers it on schedule, **whether or not Glyph is running**:

> **No sensor data** Glyph hasn't received a reading from your sensor. Keep your phone nearby.

!!! note "Nothing to snooze"

    The no-data alert fires once per gap and doesn't repeat, so its Snooze button does nothing: the next reading clears
    it, and the next gap schedules another.
