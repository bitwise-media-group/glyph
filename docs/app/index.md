---
description:
    A tour of Glyph's four tabs, and how the app lays itself out in one column on any iPhone and in two panes on the
    unfolded iPhone Duo.
---

# Tour of the app

Glyph has four tabs, and nothing hides behind menus. This page is the map; each tab has its own page.

| Tab                         | What it's for                                                                                                                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [**Now**](now.md)           | The current reading and its trend, the last three hours, today's time in range, the sensor's days left and the latest readings. |
| [**History**](history.md)   | Fourteen days of readings to scroll and scrub, with statistics and a daily pattern.                                             |
| [**Sensor**](sensor.md)     | Pairing, the sensor's state and wear, and its Bluetooth link.                                                                   |
| [**Settings**](settings.md) | Units, your target range, alerts, Health and the Live Activity.                                                                 |

Outside the app, Glyph also reaches you through [alerts](alerts.md), [widgets and a Live Activity](widgets.md), and
[Apple Health](health.md).

## One column or two

Glyph lays itself out by how much width it has, not by which phone it's on.

- **Compact width**: any iPhone, the iPhone Duo folded, or Glyph in a narrow Split View. Each tab is **one scrolling
  column**, with the tab bar along the bottom.
- **Regular width**: the iPhone Duo unfolded. Each tab splits into **two panes along the fold**. The panes sit side by
  side when the fold is vertical, and stack when it's horizontal. In landscape, iOS moves the tabs, the back button and
  the toolbar into a **vertical bar beside the status icons**, as it does in Apple's own apps.

<figure class="gl-figure gl-reveal"><div data-gl-mock="fold"></div><figcaption>
Folded, Now is one column with the tab bar. Unfold, and the reading and its chart take one side of the fold while
today and the recent readings take the other.
</figcaption></figure>

Partly open, iOS keeps both panes clear of the crease. Lying flat, the panes may run across it, so the two halves read
as one screen.

**Folding keeps your place.** The tab you're on, and on History the window, the scroll position and the time you're
scrubbing, all survive a fold or an unfold.

### What goes in which pane

| Tab      | First pane                                      | Second pane                          |
| -------- | ----------------------------------------------- | ------------------------------------ |
| Now      | The current reading; the last 3 hours           | Today; Sensor; Recent readings       |
| History  | Window picker; the scrollable chart             | 14-day statistics; the daily pattern |
| Sensor   | State and Scan / Re-pair; Wear; Before you scan | Sensor details; Bluetooth; Debug     |
| Settings | One form, no panes                              |                                      |

!!! note "Before iOS 27.1"

    The fold-aware panes need iOS 27.1. On iOS 27.0, regular width gets two equal panes side by side instead.

## Reading the colours

Everywhere Glyph shows a glucose value (the big number, the recent readings, the widgets, the Live Activity), its colour
tells you where it sits against [your target range](settings.md#display):

<div class="grid cards" markdown>

- :material-circle:{ style="color: #34c759" } **Green**: in range.
- :material-circle:{ style="color: #e6b800" } **Yellow**: above range.
- :material-circle:{ style="color: #ff9500" } **Orange**: below range.
- :material-circle:{ style="color: #ff3b30" } **Red**: urgently low, under 3.0 mmol/L (54 mg/dL).

</div>

A value that's **more than five minutes old** turns grey and is struck through, wherever it appears, so a stale number
never passes for a current one.
