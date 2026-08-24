#!/bin/sh
set -e

# Both names must match the archive in build.ncl. The 3.53.3 bump updated the
# `cd` but not the `tar`, so this extracted 3.50.4 and then changed into a
# directory that did not exist.
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
