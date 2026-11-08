#!/bin/sh
# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# Converts an lcov tracefile (stdin) to Cobertura XML (stdout): one <class> per
# source file, with line hits from the DA: records and paths made relative to
# ROOT. Codecov reads either format, but the reusable CI uploads only
# coverage/cobertura-coverage.xml (or a Go profile).
#
#   lcov-to-cobertura.sh ROOT/ <lcov.info >cobertura-coverage.xml
set -eu

root=${1:?usage: lcov-to-cobertura.sh ROOT/ <lcov.info}
awk -v root="$root" -v timestamp="$(date +%s)" '
  function flush() {
    if (file == "") return
    rate = (found > 0) ? hit / found : 1
    classes = classes sprintf("        <class name=\"%s\" filename=\"%s\" line-rate=\"%.4f\" branch-rate=\"0\" complexity=\"0\">\n          <methods/>\n          <lines>\n%s          </lines>\n        </class>\n", file, file, rate, lines)
    total_found += found; total_hit += hit
    file = ""; lines = ""; found = 0; hit = 0
  }
  /^SF:/ { flush(); file = substr($0, 4); sub("^" root, "", file) }
  /^DA:/ {
    split(substr($0, 4), parts, ",")
    lines = lines sprintf("            <line number=\"%d\" hits=\"%d\"/>\n", parts[1], parts[2])
    found++; if (parts[2] > 0) hit++
  }
  /^end_of_record/ { flush() }
  END {
    flush()
    rate = (total_found > 0) ? total_hit / total_found : 1
    printf "<?xml version=\"1.0\" ?>\n"
    printf "<coverage line-rate=\"%.4f\" branch-rate=\"0\" lines-covered=\"%d\" lines-valid=\"%d\" branches-covered=\"0\" branches-valid=\"0\" complexity=\"0\" version=\"lcov\" timestamp=\"%s\">\n", rate, total_hit, total_found, timestamp
    printf "  <sources>\n    <source>%s</source>\n  </sources>\n  <packages>\n    <package name=\"glyph\" line-rate=\"%.4f\" branch-rate=\"0\" complexity=\"0\">\n      <classes>\n%s      </classes>\n    </package>\n  </packages>\n</coverage>\n", root, rate, classes
  }
'
