#!/bin/sh
set -e

mkdir build &&
cd    build

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
