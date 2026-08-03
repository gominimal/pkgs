#!/bin/sh
set -e

# Fixed 2026-08-03: this line still named 3500400 while the `cd` below names 3530300 — a version
# bump applied to the `cd` and the sha256 but NOT to this tar line or to the Source URL. Three of
# the four places naming the version disagreed, and each one failed at a different stage.
tar -xof sqlite-autoconf-3530300.tar.gz
cd sqlite-autoconf-3530300

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA $MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

./configure  --prefix=/usr         \
            --disable-static       \
            --enable-fts4          \
            --enable-fts5          \
            --enable-rtree         \
            --enable-session

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
