#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Runs the screenshot UI tests (App/GlyphUITests) on one or more devices and
# exports every screenshot as a PNG, in a folder per device, named
# <shape>-<width>x<height>-<scenario>-<screen>.png, where the shape (portrait
# or landscape) is the window's, not the device's orientation.
#
#   scripts/screenshots.sh [destination ...]
#
# With no arguments the destinations come from $DESTINATIONS (separated by
# ';'), else the iPhone Duo and iPhone 18 Pro simulators. For a connected
# device pass 'id=<udid>'. Devices run one after another: running simulators
# side by side starves them, and the simulator then kills its own widget
# renderer. Output goes to
# $SCREENSHOTS_DIR (default .build/screenshots), replacing what was there.
# A test can rotate a device but not fold it: set the iPhone Duo's posture
# first and run once per posture, with a SCREENSHOTS_DIR for each. The
# screenshots are exported even when a test fails, and the script then exits
# with the test failure.
set -eu

if [ "$#" -eq 0 ]; then
  if [ -n "${DESTINATIONS:-}" ]; then
    old_ifs=$IFS
    IFS=';'
    # shellcheck disable=SC2086 # split on ';' on purpose
    set -- $DESTINATIONS
    IFS=$old_ifs
  else
    set -- "platform=iOS Simulator,name=iPhone Duo" \
      "platform=iOS Simulator,name=iPhone 18 Pro"
  fi
fi
for destination do
  shift
  set -- "$@" -destination "$destination"
done

out=${SCREENSHOTS_DIR:-.build/screenshots}
rm -rf "$out"
mkdir -p "$out"

status=0
xcodebuild test \
  -project Glyph.xcodeproj \
  -scheme Glyph \
  "$@" \
  -disable-concurrent-destination-testing \
  -only-testing:GlyphUITests \
  -resultBundlePath "$out/result.xcresult" \
  -derivedDataPath .build/xcode-ui || status=$?

xcrun xcresulttool export attachments --path "$out/result.xcresult" --output-path "$out/raw"

# manifest.json lists, per test run, each attachment's exported file name,
# the name the test gave it and the device; plutil reads it without extra
# tools.
manifest="$out/raw/manifest.json"
count=0
test=0
while plutil -extract "$test.attachments" json -o - "$manifest" >/dev/null 2>&1; do
  index=0
  while file=$(plutil -extract "$test.attachments.$index.exportedFileName" raw -o - "$manifest" 2>/dev/null); do
    name=$(plutil -extract "$test.attachments.$index.suggestedHumanReadableName" raw -o - "$manifest")
    device=$(plutil -extract "$test.attachments.$index.deviceName" raw -o - "$manifest" 2>/dev/null || echo device)
    case "$file" in
      *.png)
        base=${name%.png}
        mkdir -p "$out/$device"
        cp "$out/raw/$file" "$out/$device/${base%%_[0-9]*_*}.png"
        count=$((count + 1))
        ;;
    esac
    index=$((index + 1))
  done
  test=$((test + 1))
done
echo "screenshots: $count in $out"
exit "$status"
