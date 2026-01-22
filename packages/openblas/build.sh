#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

DYNAMIC_ARCH=1 make
DESTDIR="$OUTPUT_DIR" PREFIX=/usr make install
