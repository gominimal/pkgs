#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"

mkdir -p "$OUTPUT_DIR/usr/lib/minimal"
# shellcheck disable=SC2086
gcc $CFLAGS -shared -fPIC -O2 -Wall -Wextra -Wl,--build-id=none \
  -o "$OUTPUT_DIR/usr/lib/minimal/libdetbuild.so" detbuild.c
