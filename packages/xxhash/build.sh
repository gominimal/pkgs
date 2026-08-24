#!/bin/bash
set -euo pipefail


export CC=gcc
export CFLAGS="-O3 -pipe -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

make -j$(nproc) DESTDIR=$OUTPUT_DIR PREFIX=/usr install
