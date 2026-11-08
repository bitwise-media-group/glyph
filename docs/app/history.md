---
description:
    The History tab — fourteen days of readings in a scrollable, scrubbable chart, with average, GMI, time in ranges,
    variability and an ambulatory glucose profile.
---

# History

History holds the last **fourteen days**. The chart is for finding a moment; the statistics and the daily pattern under
it are for seeing the shape of the fortnight.

<div class="gl-split" markdown>
<div markdown>

## The chart

**Pick a window** with the control at the top: **3 h**, **6 h**, **12 h** or **24 h**. That's how much of the day fits
across the screen. It opens on 6 hours.

**Scroll sideways** to go back in time, as far as fourteen days.

**Scrub** to read an exact value: touch and hold on the chart, then slide. A line follows your finger, with the value
and time above it.

Like the Now chart, it draws your target range as a green band, and your low and high alert thresholds as dashed lines
while those alerts are on.

Points on this chart are **five-minute averages**, which keeps fourteen days light enough to scroll smoothly. At the
3-hour window that's still plenty of detail.

</div>
<figure class="gl-figure"><div data-gl-mock="history"></div><figcaption>
Scrubbing the 6-hour window.
</figcaption></figure>
</div>

## Last 14 days

A card of statistics over every reading in the period:

| Statistic            | What it is                                                                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Average**          | The mean of every reading.                                                                                                                               |
| **GMI**              | Glucose management indicator: an estimate of HbA1c from the average, as a percentage (3.31 + 0.02392 × the average in mg/dL). **It isn't a lab result.** |
| **Time in range**    | The share of readings inside your target range.                                                                                                          |
| **Variability (CV)** | The coefficient of variation: the standard deviation as a percentage of the average. Lower is steadier.                                                  |
| **Below range**      | Very low plus low: everything under your range.                                                                                                          |
| **Above range**      | High plus very high: everything over it.                                                                                                                 |

Under them is the same five-band bar as **Today** on Now, from very low (under 3.0 mmol/L, 54 mg/dL) through to very
high (over 13.9 mmol/L, 250 mg/dL), and the number of readings it's all worked out from.

## Daily pattern

An **ambulatory glucose profile** (AGP): all fourteen days folded onto one 24-hour axis, so you can see what a typical
day looks like.

<figure class="gl-figure gl-reveal"><div data-gl-mock="agp"></div><figcaption>
The line is the median at each time of day. The darker band holds the middle half of readings (25th to 75th
percentile), and the lighter one nine in ten (5th to 95th).
</figcaption></figure>

- A **high, wide band** after breakfast means breakfasts vary a lot.
- A **median that drifts up overnight** shows on every night at once, where it would be easy to miss day by day.
- Times of day with fewer than three readings are left out rather than guessed.

!!! tip "Use it with your care team"

    GMI, time in range, CV and the AGP are the measures most diabetes clinics use, so these numbers are comparable to
    the reports they produce. They come from Glyph's readings, though, which aren't certified.
