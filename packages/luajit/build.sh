#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
export CFLAGS="-O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"

# amalg is the upstream-recommended release build (single amalgamated
# translation unit, better optimization).
make -j"$(nproc)" amalg PREFIX=/usr \
  TARGET_CFLAGS="$CFLAGS" TARGET_LDFLAGS="$LDFLAGS"
make install PREFIX=/usr DESTDIR="$OUTPUT_DIR"
