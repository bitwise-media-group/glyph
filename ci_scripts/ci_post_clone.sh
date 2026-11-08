#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Xcode Cloud runs this once per build, straight after cloning. It runs the
# Foundation-only package tests first (LibreKit, the sensor protocol, and
# GlyphCore, the app logic), so a broken decoder or alert rule fails the build
# before anything is archived or reaches TestFlight. They take about a minute.
# Xcode Cloud has no mise, so this uses Xcode's own Swift.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcrun swift --version
xcrun swift test
