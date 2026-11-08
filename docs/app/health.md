---
description: How Glyph writes blood glucose to Apple Health — write-only, never duplicated, and easy to turn off.
---

# Apple Health

Glyph can save every reading to the Health app as **blood glucose**, so other apps you trust, and your Health records,
can use them.

## Turn it on

<div class="gl-steps" markdown>

1. Open **Settings** in Glyph and turn on **Save to Health**.
2. iOS asks which data Glyph may write. Allow **Blood Glucose**.

</div>

If you don't allow it, the switch turns itself off again. On a device without Health it's greyed out.

## What Glyph writes

- **Every reading from a real sensor**, from the moment you turn it on, including the ones back-filled when you pair.
  Readings from the [simulated sensor](settings.md#debug) never go to Health.
- Each sample is **blood glucose in mg/dL** (Health converts it to your preferred unit), timed when the sensor took it,
  from a device named **FreeStyle Libre 2**, marked as **not entered by hand**.

## What Glyph doesn't do

- **It never reads from Health.** It asks for write permission only.
- **It never writes a reading twice.** Each sample carries a sync identifier made from the sensor's serial and the
  sensor's own minute counter. If the same reading arrives again (from a back-fill, a re-pair, or a reinstall), Health
  replaces the old sample instead of adding a second.

## Turn it off

Turn off **Save to Health** in Glyph to stop writing. To also revoke the permission, or to delete what Glyph has
written, use the Health app: <span class="gl-path">Health ▸ your profile ▸ Apps ▸ Glyph</span>.
