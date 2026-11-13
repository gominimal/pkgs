#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

# TERMINFO_DIRS is pinned: upstream's cmake probes ncurses*-config for the
# default, which would silently vary with the build environment.
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DTERMINFO_DIRS=/etc/terminfo:/lib/terminfo:/usr/share/terminfo
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
# Upstream's CMake gzips the 53 man pages with plain `gzip`, which stamps the current
# time into each header, so every build differed in 53 of 57 files (2026-10 prod-pair
# diff) while the decompressed pages were identical. Recompress without the timestamp.
find "$OUTPUT_DIR/usr/share/man" -name '*.gz' -type f | while read -r f; do
  gzip -dc "$f" | gzip -9n > "$f.tmp" && mv "$f.tmp" "$f"
done
