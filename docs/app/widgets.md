---
description:
    Glyph's Home Screen and Lock Screen widgets, and the Live Activity on the Lock Screen, in the Dynamic Island and on
    the iPhone Duo's outer display.
---

# Widgets & Live Activity

You don't have to open Glyph to see your glucose. Widgets put it on the Home Screen and Lock Screen; the Live Activity
keeps it current, reading by reading, on the Lock Screen and in the Dynamic Island.

## Widgets

One widget, **Glucose**, in five sizes: your latest reading, its trend arrow and its age, coloured like everywhere else.

<figure class="gl-figure gl-reveal"><div data-gl-mock="widgets"></div><figcaption>
Home Screen: small and medium, each with the last hour. Lock Screen: inline, circular and rectangular.
</figcaption></figure>

| Where       | Size            | Shows                                                         |
| ----------- | --------------- | ------------------------------------------------------------- |
| Home Screen | **Small**       | The reading, trend and age, over a sparkline of the last hour |
| Home Screen | **Medium**      | The same plus the change, beside a chart of the last hour     |
| Lock Screen | **Circular**    | The reading and trend arrow                                   |
| Lock Screen | **Rectangular** | The reading, trend and age, with a sparkline                  |
| Lock Screen | **Inline**      | One line above the clock                                      |

Before a sensor is paired, the widgets say **Open Glyph to pair**.

**To add one**, touch and hold the Home Screen or Lock Screen, tap **Edit** (or **Customise**), then **Add Widget**, and
choose **Glyph**.

!!! info "Widgets refresh every five minutes"

    iOS gives each app a daily budget of widget refreshes, so Glyph refreshes its widgets **at most every five
    minutes**, not on every reading. A widget can be a few minutes behind; its age tells you how far. A reading more
    than five minutes old is shown grey and struck through. For a value that's always current, use the Live Activity.

## Live Activity

The Live Activity updates with **every reading**, about once a minute, straight from Glyph. No server is involved.

<div class="gl-split" markdown>
<div markdown>

It appears in four places:

- **The Lock Screen**: the reading and trend, the change and age, and a sparkline of the last hour.
- **StandBy**, when the phone is charging on its side.
- **The Dynamic Island**: compact, the reading on one side and the arrow on the other. Touch and hold for the expanded
  view, with the change, the age and the sparkline.
- **The iPhone Duo's outer display**, when it's folded.

Each update is marked stale after **five minutes**: if readings stop, the value dims and is struck through.

**It starts by itself** when streaming begins and the Live Activity setting is on. iOS only lets an app start one while
it's open, so if streaming begins in the background, it appears the next time you open Glyph.

**Turn it off** in [Settings ▸ Sharing ▸ Live Activity](settings.md#sharing), which also ends the one that's showing. To
stop it for all apps, use <span class="gl-path">Settings ▸ Apps ▸ Glyph ▸ Live Activities</span>.

</div>
<figure class="gl-figure"><div data-gl-mock="lock-live"></div><figcaption>On the Lock Screen.</figcaption></figure>
</div>

<figure class="gl-figure gl-reveal"><div data-gl-mock="island"></div><figcaption>
In the Dynamic Island: compact, then expanded.
</figcaption></figure>
