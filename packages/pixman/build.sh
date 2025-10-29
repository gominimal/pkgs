#!/bin/sh
set -e

mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
