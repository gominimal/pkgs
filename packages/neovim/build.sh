#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

# All third-party deps (luajit, libuv, luv, lpeg, unibilium, utf8proc,
# tree-sitter and the grammar parsers) come from the registry, so upstream's
# cmake.deps download step is skipped entirely.
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
