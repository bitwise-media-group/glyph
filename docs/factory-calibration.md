# Factory calibration: specification

This is the plain-language specification that `Sources/LibreKit/Calibration/FactoryCalibration.swift` is written from.
It describes the maths only. It is not a translation of any implementation.

**Provenance warning.** This conversion first appeared publicly in xdripswift (GPL-3.0, 2020). The MIT-licensed projects
that carry it (DiaBLE, GlucoseDirect, LibreTransmitter) credit xdripswift as their source, so the MIT status of this
piece is doubtful. Glyph keeps it alone in one file behind the `GlucoseConverter` protocol, and the `NOTICE` file flags
it. **Get a legal opinion before the repository is made public**, and be ready to replace this file (for example with a
fingerstick-based `LinearCalibration`).

## Inputs

From each sensor record:

- `raw`: the 14-bit glucose signal.
- `rawTemperature`: the thermistor reading (the stored 12-bit field multiplied by 4).
- `temperatureAdjustment`: a signed correction (the stored magnitude multiplied by 4, negated when its sign bit is set).

From the sensor's FRAM, once per sensor:

- `i2`: a 10-bit sensitivity code, 1 to 1023.
- `i3`: a signed raw offset.
- `i4`: the raw value at the reference point.
- `i6`: a thermistor reference (multiplied by 4).

`i1` and `i5` are read and stored but take no part in the conversion.

## Steps

1. **Sensor temperature.** The thermistor sits in a divider with 71.5 kΩ and 1 kΩ resistors. Its resistance is

   `R = 72 500 × rawTemperature / (temperatureAdjustment + i6) − 1 000` ohms.

   The temperature follows from a Steinhart–Hart-style cubic in the natural logarithm of `R`:

   `1 / T(K) = a + b·ln R + c·(ln R)² + d·(ln R)³`

   with `a = 9.180023 × 10⁻⁴`, `b = 1.964561 × 10⁻⁴`, `c = 7.061775 × 10⁻⁷` and `d = 5.283566 × 10⁻⁸`. Convert to
   Celsius by subtracting 273.15.

2. **Normalised signal.** Map the raw value onto a 0–65 scale, using the two calibration points:

   `s = 65 × (raw − i3) / (i4 − i3)`.

3. **Temperature compensation.** The signal changes by 4.5 % per degree. Bring it to the reference temperature of
   32.5 °C:

   `s′ = s × 1.045^(32.5 − T)`.

4. **Sensitivity.** The code `i2` selects an offset and a slope from a grid of 1 023 cells. Glucose is

   `mg/dL = (s′ − offset) / slope`, rounded to the nearest whole number.

## The sensitivity grid

The cells are numbered `n = i2 − 1` (0 to 1022). They are laid out in rows. Every cell in a row has the same slope, and
the offsets step across the row in increments of 0.25. The rows come in four bands:

| band | rows      | cells per row | first offset in the row | cells (`n`) |
| ---- | --------- | ------------- | ----------------------- | ----------- |
| A    | 0 – 63    | 8             | 0.75                    | 0 – 511     |
| B    | 64 – 86   | 9             | 0.75                    | 512 – 718   |
| C    | 87 – 115  | 8             | 1.00                    | 719 – 950   |
| D    | 116 – 123 | 9             | 1.00                    | 951 – 1022  |

So the offsets run 0.75 to 2.5 in band A, 0.75 to 2.75 in band B, 1.0 to 2.75 in band C and 1.0 to 3.0 in band D.

The slope grows by 1 % per row:

`slope(row) = 0.0377442272 × 1.01^row`, rounded to 7 decimal places.

The rounding reproduces the grid as it has been published, exactly. Without the rounding, results move by much less than
0.01 mg/dL.

## Edge cases

The conversion yields no value when:

- the record carries an error (`raw` is 0);
- `i4 = i3`;
- `i2` is outside 1 to 1023;
- `R ≤ 0`;
- any intermediate result is not finite.

Clamping to the sensor's reporting range (40 to 500 mg/dL, shown as LO and HI) is a display concern. It is not part of
the conversion.
