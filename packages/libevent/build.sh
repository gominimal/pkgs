#!/bin/sh
set -e

./configure --prefix=/usr --disable-static
make -j$(nproc)
# make check

make DESTDIR="$OUTPUT_DIR" install
