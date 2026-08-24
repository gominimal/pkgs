#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
CFLAGS="${CFLAGS:-} -O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"

# Same shape as neovim's bundled-parser recipe: all of src/ compiled into a
# <lang>.so loadable from nvim's runtime 'parser/' directory.
mkdir -p "$OUTPUT_DIR/usr/lib/nvim/parser"
gcc $CFLAGS -std=c11 -fPIC -I src -shared src/*.c \
  -Wl,--build-id=none -o "$OUTPUT_DIR/usr/lib/nvim/parser/c.so"
