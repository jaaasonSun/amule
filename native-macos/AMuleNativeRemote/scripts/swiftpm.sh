#!/usr/bin/env bash
set -euo pipefail

# Keep SwiftPM intermediates out of the repository and avoid generating the
# source index store during non-interactive CI/agent builds.
BUILD_PATH="${AMULE_SPM_BUILD_PATH:-${TMPDIR:-/tmp}/amule-spm-build}"

mkdir -p "$BUILD_PATH"
exec swift "$@" --build-path "$BUILD_PATH" --disable-index-store
