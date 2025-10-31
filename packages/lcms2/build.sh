#!/bin/sh
set -e

./configure --prefix=/usr --disable-static
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
