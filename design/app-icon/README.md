# App icon

Glyph's app icon, as an Icon Composer file for the layered Liquid Glass icons in iOS 27. `AppIcon.icon` opens in Icon
Composer as it is.

![The icon in its default, dark and tinted appearances, and as a circle for watchOS](preview.png)

The preview is a flat approximation, with no Liquid Glass. Icon Composer shows the real rendering.

## Design

A sensor disc with a glucose wave running through it and the current reading at its centre. The colours are the BitWise
palette from [dotty](https://oss.bitwisemedia.uk/dotty/): warm paper and near black for the canvas, and its yellow ramp,
from amber to yellow, for the wave. Each shape is its own group, so the system gives each one its own glass, highlights
and shadow. Back to front:

| Group   | Layer           | Shape                        | Default                | Dark                   |
| ------- | --------------- | ---------------------------- | ---------------------- | ---------------------- |
| Base    | `1-base.svg`    | The sensor's rim             | `#E6DECB`              | `#C8C0A4`, 55%         |
| Face    | `2-face.svg`    | Its raised face              | `#FFFDF7`              | `#F4EFDD`              |
| Wave    | `3-wave.svg`    | The glucose wave, full width | `#A85A00` to `#E6B400` | `#E0A800` to `#FFD740` |
| Reading | `4-reading.svg` | The current reading          | `#211E14`              | `#15140F`              |

The background is `#FBF8ED`, and `#15140F` in dark mode. The wave's group casts a shadow in its own colour, so it glows
a little. Tinted and clear are left to the system, which derives them from the default appearance.

It follows the [app icon guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons):

- A 1024 pt canvas, with every layer a full-canvas SVG so the layers stay aligned when they're imported.
- Opaque white artwork with no background, mask, blur, shadow, highlight or opacity. Icon Composer adds those, and sets
  each layer's colour.
- Vector art only, with the wave's stroke outlined into a filled shape.
- The disc and the reading are centred inside the inscribed circle, so the same layers work for a watchOS icon. The wave
  runs off the edges and is cropped by the mask.
- Up to four groups. This uses all four.

## Files

- `AppIcon.icon`: the Icon Composer file. `icon.json` holds the background, the colours and the glass settings, and
  `Assets/` holds the layers.
- `generate.py`: regenerates the layer SVGs from their geometry. From the repository root:

  ```sh
  pip install skia-pathops fonttools
  python3 design/app-icon/generate.py design/app-icon/AppIcon.icon/Assets
  ```

- `preview.png`: the flat preview above.

## Using it in the app

The app doesn't use this file yet. Its `AppIcon.appiconset` is still empty. To use it, add `AppIcon.icon` to the Glyph
target in `project.yml` so it lands in the app's resources, and remove `AppIcon.appiconset`, since Xcode uses the Icon
Composer file in its place. The target's `ASSETCATALOG_COMPILER_APPICON_NAME` is already `AppIcon`, which matches the
file's name.
