#!/bin/sh
set -e

tar -xof sqlite-autoconf-3500400.tar.gz
cd sqlite-autoconf-3500400

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
