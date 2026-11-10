#!/bin/sh
set -e

tar -xof lz4-1.11.0.tar.gz
cd lz4-1.11.0

export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
# 1.11.0's multiconf build re-resolves the phony `lz4` target with the flags of
# each make invocation, so `lz4-release`'s -DNDEBUG would not survive into
# `install`'s rebuild. Set it for every invocation instead.
export CPPFLAGS="-DNDEBUG"

# No separate default build: in 1.11.0, `lib`/`lib-release` require liblz4.a
# even with BUILD_STATIC=no (the rule only exists when it is yes), so the
# default target fails. `install` builds exactly what BUILD_STATIC/BUILD_SHARED
# select (the lz4 CLI and the shared liblz4).
# make -j1 check
make -j$(nproc) BUILD_STATIC=no PREFIX=/usr DESTDIR=$OUTPUT_DIR install
