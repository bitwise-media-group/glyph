# Copyright 2026 BitWise Media Group Ltd
# SPDX-License-Identifier: MIT
#
# glyph — everything lives in mise tasks: the common tasks (license, prose,
# workflow and shell lint) come from the shared toolchain submodule at .mise/,
# and tasks.toml adds the Swift build, test, fmt and lint plus the Xcode
# gen/app-build. This Makefile is only the thin forwarding shim —
# `make <task>` == `mise run <task>`.
MISE_TASKS += gen app-build screenshots
include .mise/common/include.mk
