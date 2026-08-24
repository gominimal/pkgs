#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md). lpeg's makefile composes CFLAGS
# itself, so the extra flags go in via COPT and the linker flags via DLLFLAGS.
COPT="-O2 -DNDEBUG -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"

make lpeg.so LUADIR=/usr/include/luajit-2.1 COPT="$COPT" \
  DLLFLAGS="-shared -fPIC -Wl,--build-id=none"

install -D -m 755 lpeg.so "$OUTPUT_DIR/usr/lib/lua/5.1/lpeg.so"
install -D -m 644 re.lua "$OUTPUT_DIR/usr/share/lua/5.1/re.lua"
