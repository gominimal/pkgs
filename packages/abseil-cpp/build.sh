#!/bin/sh
set -e

# gcc-15 rejects abseil's direct `#include <bmi2intrin.h>` (raw_hash_set.h)
# under -march=x86-64-v3 (which defines __BMI2__) — swap it for the sanctioned
# `<x86intrin.h>` umbrella header, exactly as gcc's own diagnostic advises.
patch -Np1 -i "abseil-cpp-gcc15-bmi2intrin.patch"

mkdir build &&
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_INSTALL_PREFIX=/usr      \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib  \
      -D CMAKE_BUILD_TYPE=Release       \
      -D ABSL_PROPAGATE_CXX_STD=ON      \
      -D BUILD_SHARED_LIBS=ON           \
      -G Ninja ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
