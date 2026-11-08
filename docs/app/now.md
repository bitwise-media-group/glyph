---
description:
    The Now tab shows the current reading with its trend, the last three hours, today's time in range, the sensor's days
    left and the latest readings.
---

# Now

Now is where Glyph opens. It answers "what is my glucose, and where is it going?" at a glance, then gives you the last
three hours and today underneath.

<div class="gl-split" markdown>
<div markdown>

The screen is made of five cards. On the folded iPhone Duo, or any iPhone, they form one scrolling column. Unfolded, the
first two (the reading and the chart) sit on one side of the fold, and the other three on the other side.

1. **The current reading**: the value, its trend arrow, how much it changed and how long ago it arrived.
2. **Last 3 hours**: a chart of every reading since three hours ago.
3. **Today**: time in range since midnight.
4. **Sensor**: how long the sensor has left.
5. **Recent readings**: the last 15 values.

The mockup is running a simulated sensor, so it updates every few seconds. On your arm, a new reading arrives about once
a minute.

</div>
<figure class="gl-figure"><div data-gl-mock="now"></div><figcaption>The Now tab, compact width.</figcaption></figure>
</div>

## The current reading

The big number is your latest glucose value, in the unit you chose in [Settings](settings.md#display) (mmol/L unless you
change it).

Its **colour** says where it sits against your target range:

| Colour | Means                       | With the default range             |
| ------ | --------------------------- | ---------------------------------- |
| Green  | In range                    | 3.9–10.0 mmol/L (70–180 mg/dL)     |
| Yellow | Above range                 | over 10.0 mmol/L (180 mg/dL)       |
| Orange | Below range                 | under 3.9 mmol/L (70 mg/dL)        |
| Red    | Urgently low                | under 3.0 mmol/L (54 mg/dL)        |
| Grey   | Stale: no reading for 5 min | struck through, whatever the value |

The **trend arrow** comes from the sensor's own readings over the last few minutes:

| Arrow | Means            | Rate of change                                      |
| :---: | ---------------- | --------------------------------------------------- |
|   ⇈   | Rising quickly   | more than 0.17 mmol/L (3 mg/dL) a minute            |
|   ↑   | Rising           | 0.11–0.17 mmol/L (2–3 mg/dL) a minute               |
|   ↗   | Rising slightly  | 0.06–0.11 mmol/L (1–2 mg/dL) a minute               |
|   →   | Steady           | less than 0.06 mmol/L (1 mg/dL) a minute either way |
|   ↘   | Falling slightly | 0.06–0.11 mmol/L (1–2 mg/dL) a minute               |
|   ↓   | Falling          | 0.11–0.17 mmol/L (2–3 mg/dL) a minute               |
|   ⇊   | Falling quickly  | more than 0.17 mmol/L (3 mg/dL) a minute            |
|   –   | Unknown          | not enough recent readings yet                      |

Under the value, **±** is the change over the last five minutes, and the clock shows the reading's age: "Just now", then
"1 min ago", "2 min ago" and so on.

### When there's no reading

If the sensor isn't streaming, a line in orange under the value says why:

| Message                                       | What to do                                                                           |
| --------------------------------------------- | ------------------------------------------------------------------------------------ |
| No sensor paired. Scan one on the Sensor tab. | [Pair a sensor](../getting-started/pair-a-sensor.md).                                |
| Waiting for the first reading…                | Nothing: Glyph is paired and connecting. Give it a minute.                           |
| Sensor warming up: readings in _N_ min.       | Nothing: a new sensor's first hour gives no readings.                                |
| Signal lost. Keep your phone near the sensor. | Bring the phone closer. See [Troubleshooting](troubleshooting.md#signal-lost).       |
| Sensor ended. Scan a new one.                 | [Replace the sensor](../getting-started/sensor-life.md#replacing-a-sensor).          |
| Anything else                                 | The pairing failed. The message says why; see [Troubleshooting](troubleshooting.md). |

## Last 3 hours

A line chart of every reading from the last three hours. The **green band** is your target range. The **dashed lines**
are your low and high alert thresholds, drawn only while those alerts are on, so you can see how close you came.

## Today

Your **time in range** since midnight, as a percentage, with a bar that splits the day into five bands:

- **Red**: very low, under 3.0 mmol/L (54 mg/dL)
- **Orange**: low, from there to the bottom of your range
- **Green**: in range
- **Yellow**: high, from the top of your range to 13.9 mmol/L (250 mg/dL)
- **Amber**: very high, over 13.9 mmol/L (250 mg/dL)

## Sensor

How many **days are left** on the sensor, to one decimal place, with a bar for the wear so far and the day and time it
ends. The bar turns orange in the last 24 hours, so you know to have a new sensor ready.

## Recent readings

The last 15 readings, newest first, each coloured like the big number. Readings are spaced about a minute apart while
streaming. When Glyph back-fills after pairing, older ones can be 15 minutes apart.

!!! tip "See more"

    For anything older than three hours, open [History](history.md). Its chart scrolls back fourteen days.
