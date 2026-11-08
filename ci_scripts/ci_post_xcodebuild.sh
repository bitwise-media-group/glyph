#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Xcode Cloud runs this after each xcodebuild action. After an archive signed
# for App Store Connect (a TestFlight build) it writes TestFlight's "What to
# Test" notes from the latest commit subjects: Xcode Cloud picks up
# TestFlight/WhatToTest.<locale>.txt from the repository root. Other actions
# do nothing.
set -eu

if [ -z "${CI_APP_STORE_SIGNED_APP_PATH:-}" ] || [ ! -d "$CI_APP_STORE_SIGNED_APP_PATH" ]; then
  exit 0
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"
mkdir -p TestFlight
# Xcode Cloud clones shallowly; fetch enough history for the notes.
git fetch --deepen 10 --quiet 2>/dev/null || true
{
  echo "Glyph build ${CI_BUILD_NUMBER:-?} from ${CI_TAG:-${CI_BRANCH:-unknown}}."
  echo "Personal software, not a medical device."
  echo
  git log -10 --pretty=format:'- %s' || true
  echo
} >TestFlight/WhatToTest.en-US.txt
cat TestFlight/WhatToTest.en-US.txt
