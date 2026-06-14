#!/bin/sh
set -e

mkdir build && cd build
meson setup --wrap-mode=nodownload --prefix=/usr --buildtype=release ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
