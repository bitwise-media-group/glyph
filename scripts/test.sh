#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# swift test with coverage, then the two files the reusable CI uploads:
#   coverage/junit.xml               Swift Testing results (JUnit XML)
#   coverage/cobertura-coverage.xml  line coverage of Sources/, as Cobertura
# llvm-cov comes from the same toolchain as swift (the core:swift mise pin,
# or Xcode / the Command Line Tools through xcrun).
set -eu

mkdir -p coverage
swift test --enable-code-coverage --xunit-output coverage/xunit.xml "$@"
# Swift Testing writes its results beside the XCTest file, as <name>-swift-testing.xml
if [ -f coverage/xunit-swift-testing.xml ]; then
  mv coverage/xunit-swift-testing.xml coverage/junit.xml
fi
rm -f coverage/xunit.xml

bin=$(swift build --show-bin-path)
profile="$bin/codecov/default.profdata"
if [ -d "$bin/GlyphPackageTests.xctest/Contents/MacOS" ]; then
  binary="$bin/GlyphPackageTests.xctest/Contents/MacOS/GlyphPackageTests" # macOS bundle
else
  binary="$bin/GlyphPackageTests.xctest" # Linux executable
fi

llvm_cov=$(command -v llvm-cov || true)
if [ -z "$llvm_cov" ]; then
  swift_path=$(command -v swift)
  real_swift=$(readlink -f "$swift_path" 2>/dev/null || printf '%s' "$swift_path")
  if [ -x "$(dirname "$real_swift")/llvm-cov" ]; then
    llvm_cov="$(dirname "$real_swift")/llvm-cov"
  else
    llvm_cov=$(xcrun --find llvm-cov)
  fi
fi

"$llvm_cov" export -format=lcov -instr-profile "$profile" "$binary" \
  -ignore-filename-regex '(\.build|Tests)/' >coverage/lcov.info

"$(dirname "$0")/lcov-to-cobertura.sh" "$(pwd)/" <coverage/lcov.info >coverage/cobertura-coverage.xml
rm -f coverage/lcov.info
echo "coverage: $(sed -n 's/.*<coverage line-rate="\([0-9.]*\)".*/\1/p' coverage/cobertura-coverage.xml) line rate -> coverage/cobertura-coverage.xml"
