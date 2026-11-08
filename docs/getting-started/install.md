---
description:
    Install Glyph on your iPhone from TestFlight or by building it in Xcode, and grant the permissions it asks for on
    first launch.
---

# Install Glyph

Glyph is personal software, so it doesn't come from the App Store. Pick whichever of these fits you.

=== "From TestFlight"

    If someone who builds Glyph has invited you to test it:

    <div class="gl-steps" markdown>

    1. Install **TestFlight** from the App Store.
    2. Open the invitation email or link on your iPhone, and tap **Accept**.
    3. In TestFlight, tap **Install** next to Glyph.

    </div>

    TestFlight builds expire after 90 days. TestFlight tells you when a new one is ready, and installing it keeps your
    readings and settings.

=== "From Xcode"

    You need a Mac with **Xcode 27.2 or later** and a **paid Apple Developer account**: NFC tag reading, HealthKit, App
    Groups and time-sensitive notifications all need one.

    <div class="gl-steps" markdown>

    1. Clone the repository with its toolchain submodule, and trust its tool config:

        ```sh
        git clone --recurse-submodules https://github.com/bitwise-media-group/glyph.git
        cd glyph
        mise trust
        ```

    2. Set your own team. In `project.yml`, change `DEVELOPMENT_TEAM` to your team ID, and the bundle IDs and the App
       Group (`uk.co.bitwisemedia.glyph…`, `group.uk.co.bitwisemedia.glyph`) to ones your team owns. Change them there,
       not in Xcode, because the project is generated from that file.

    3. Regenerate the project and open it:

        ```sh
        mise run gen
        open Glyph.xcodeproj
        ```

    4. Plug in your iPhone, choose it as the run destination, and press ++cmd+r++.

    </div>

    [Local setup](../development/setup.md) has the details, including how to work without a sensor.

## First launch

Glyph asks for three things the first time you need them. All three matter.

| Permission        | When it asks                     | Why                                                                         |
| ----------------- | -------------------------------- | --------------------------------------------------------------------------- |
| **Notifications** | At first launch                  | Alerts. Allow them, and allow **Time Sensitive** notifications too.         |
| **Bluetooth**     | When it first looks for a sensor | Receiving readings. Without it the Sensor tab says "Bluetooth not allowed". |
| **Health**        | When you turn on Save to Health  | Optional: writing readings to the Health app.                               |

NFC needs no permission: iOS shows its scanning sheet each time you scan.

!!! tip "Check Focus"

    Glyph's alerts are time-sensitive, so they break through Focus. If you've turned off time-sensitive notifications
    for Glyph in **Settings ▸ Notifications ▸ Glyph**, turn them back on.

Glyph opens on **Now**, which says "No sensor paired" until you scan one. That's next:
[Pair a new sensor](pair-a-sensor.md).
