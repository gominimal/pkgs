#!/bin/bash
set -euo pipefail

# PGXS build against the postgres package's pg_config. OPTFLAGS="" drops
# upstream's default -march=native, which would tie the binary to the build
# host's CPU.
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
make -j"$(nproc)" OPTFLAGS="$MARCH" \
  PG_CFLAGS="-gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
make DESTDIR="$OUTPUT_DIR" install
