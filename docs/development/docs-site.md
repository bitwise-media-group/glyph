---
description:
    How this documentation site is built with Zensical, previewed locally, published, and how its animated app mockups
    work.
---

# This site

These docs are a [Zensical](https://zensical.org) site, in dotty's theme: the same warm paper, near-black and yellow
ramp as the app icon.

## Preview and build

```sh
mise run serve        # live preview at http://localhost:8003
mise run docs-build   # build into site/
```

Both come from the toolchain's common tasks. They run `uv sync`, which installs Python and Zensical from
`pyproject.toml` and `uv.lock` into `.venv/`, then run Zensical from there. `site/` and `.venv/` are git-ignored.

The release workflow builds the site and publishes it to GitHub Pages, at
[oss.bitwisemedia.uk/glyph](https://oss.bitwisemedia.uk/glyph/).

## Where things are

```text
zensical.toml                  site config: navigation, theme, extensions
pyproject.toml, uv.lock        the Zensical pin
docs/                          the pages (Markdown)
docs/stylesheets/extra.css     the theme: tokens, chrome, landing page, app mockups, animations
docs/javascripts/glyph.js      draws the app mockups and runs their animations
docs/assets/favicon.svg        the app icon, flattened for the web
overrides/home.html            the landing page
overrides/partials/            the header and drawer wordmark, and the inline app icon
```

`docs/factory-calibration.md` lives in `docs/` beside the pages but is listed in `exclude_docs`, so it isn't published.
See [House rules](rules.md#licensing-and-provenance).

## Adding a page

1. Write it under `docs/`, with a `description:` in its front matter for search engines and link previews.
2. Add it to `nav` in `zensical.toml`.
3. `mise run fmt` formats it to the house style (120 columns), and `mise run lint` checks it.

## App mockups

The pictures of the app are drawn in HTML and CSS, not screenshots, so they follow the light and dark toggle, stay sharp
at any size, and can move. A page asks for one with an empty placeholder:

```html
<figure class="gl-figure gl-reveal">
    <div data-gl-mock="now"></div>
    <figcaption>…</figcaption>
</figure>
```

and `docs/javascripts/glyph.js` draws it. Keep the whole figure on one line: a blank line inside an HTML block ends it
in Markdown.

| `data-gl-mock` | Draws                                                                     |
| -------------- | ------------------------------------------------------------------------- |
| `now`          | The Now tab on a phone, with a simulated sensor ticking every few seconds |
| `duo`          | Now on the unfolded iPhone Duo, two panes and the vertical tab bar, live  |
| `fold`         | The Duo folding and unfolding between one column and two panes            |
| `history`      | The History tab, scrubbing the chart                                      |
| `agp`          | The daily pattern (AGP) card                                              |
| `sensor`       | The Sensor tab. `data-phase`: `streaming`, `warming`, `none` or `lost`    |
| `settings`     | Settings, with working switches and unit picker                           |
| `lock-alert`   | A low alert arriving on the Lock Screen, then its Snooze action           |
| `lock-live`    | The Live Activity on the Lock Screen                                      |
| `island`       | The Live Activity in the Dynamic Island, compact then expanded            |
| `widgets`      | The Home Screen and Lock Screen widgets                                   |
| `scan`         | The NFC scan: the phone's top edge to the sensor                          |
| `lifecycle`    | A sensor's life, stepping through each stage                              |
| `pipeline`     | The six steps every reading goes through                                  |

Add `data-live="false"` to stop a live mockup ticking. Add `gl-reveal` to any block to fade it in as it scrolls into
view.

Every animation is decoration. With **reduce motion** turned on, each figure shows its resting state instead: the chart
drawn, the island expanded, the Duo open.

When the app changes, change the mockup to match: the screens are built from the same cards, in the same order, as the
SwiftUI views in `App/Glyph/Features/`.
