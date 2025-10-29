#!/bin/sh
set -e

mkdir build &&
cd    build

meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
