#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Reproducibility: NSPR stamps a wall-clock build time into the library version
# string (config/now.c -> _BUILD_TIME, and `date` -> _BUILD_STRING) and ignores
# SOURCE_DATE_EPOCH. Override the two make vars the version header is built from:
# SH_NOW="" omits _BUILD_TIME (defaults to 0 in prvrsion.c); SH_DATE is pinned
# from SOURCE_DATE_EPOCH.
export SOURCE_DATE_EPOCH=0
BUILD_DATE="$(date -u -d "@${SOURCE_DATE_EPOCH}" '+%Y-%m-%d %T')"

cd nspr
./configure --prefix=/usr --disable-static --enable-64bit
make -j$(nproc) SH_DATE="$BUILD_DATE" SH_NOW=
make DESTDIR=$OUTPUT_DIR install
