# App Store assets

Glyph's App Store artwork, following Apple's
[asset best practices](https://developer.apple.com/app-store/asset-best-practices/), in dotty's palette with the app
icon's sensor and wave. App previews (video) aren't included.

Every asset is a layered SVG master and an opaque PNG at Apple's exact size. Pixelmator Pro opens the SVGs with each
element as its own layer and the text as editable text. The type is JetBrains Mono, which needs to be installed for the
text to look right.

## Creative assets

| File                               | Placement                                            | Size                    |
| ---------------------------------- | ---------------------------------------------------- | ----------------------- |
| `creative/universal-5244x2950`     | Product page header and search results, as one asset | 5244 × 2950 (16:9), PNG |
| `creative/header-3840x1646`        | Product page header                                  | 3840 × 1646 (21:9)      |
| `creative/search-3840x2560`        | Search results                                       | 3840 × 2560 (3:2)       |
| `creative/event-card-3840x2160`    | In-App Event card                                    | 3840 × 2160 (16:9)      |
| `creative/event-details-2160x3840` | In-App Event details page                            | 2160 × 3840 (9:16)      |

Upload either the universal asset or the header and search pair. The universal asset is cropped to 21:9 for the header
and 3:2 for search, so its sensor and tagline stay inside the area both crops keep. The In-App Event artwork has no
text, since the App Store sets the event's badge, name and description beside it.

## Screenshots

Five captioned screenshots for each display size. The captions and the capture each one uses are in `screenshots.json`.

| Folder                             | Display                                       | Size        | Captured on               |
| ---------------------------------- | --------------------------------------------- | ----------- | ------------------------- |
| `screenshots/iphone-6.9-1320x2868` | iPhone with Dynamic Island, large             | 1320 × 2868 | iPhone 18 Pro, folded run |
| `screenshots/iphone-6.3-1206x2622` | iPhone with Dynamic Island, medium (required) | 1206 × 2622 | iPhone 18 Pro, folded run |
| `screenshots/duo-outer-1398x2034`  | iPhone Duo, outer display                     | 1398 × 2034 | iPhone Duo, folded        |
| `screenshots/duo-inner-2853x2007`  | iPhone Duo, inner display (landscape)         | 2853 × 2007 | iPhone Duo, unfolded      |

The captures come from `mise run screenshots`, run once per iPhone Duo posture. Override the simulators' status bars
first so they show 9:41 and a full battery:

```sh
for d in "iPhone 18 Pro" "iPhone Duo"; do
  xcrun simctl boot "$d" 2>/dev/null
  xcrun simctl status_bar "$d" override --time 9:41 \
    --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
done
# with the Duo folded:
SCREENSHOTS_DIR=.build/screenshots/folded mise run screenshots
# then unfolded:
SCREENSHOTS_DIR=.build/screenshots/unfolded DESTINATIONS='platform=iOS Simulator,name=iPhone Duo' \
  mise run screenshots
```

## Rebuilding

`build.py` regenerates everything from the captures in `.build/screenshots`. A frame whose capture is missing gets a
placeholder SVG and no PNG, and the script lists what's missing. It needs `rsvg-convert` (`brew install librsvg`),
Pillow and JetBrains Mono. From the repository root:

```sh
pip install pillow
python3 design/app-store/build.py
```

Rebuilding overwrites the SVGs. To keep edits made in Pixelmator Pro, save them as a Pixelmator document, or change
`build.py` and `screenshots.json` instead.

## App icon

The App Store icon comes from the Icon Composer file in the build, so there's nothing to upload for it. See
[`../app-icon`](../app-icon/README.md).
