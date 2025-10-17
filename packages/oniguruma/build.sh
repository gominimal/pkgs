#!/bin/sh
set -e

./configure --prefix=/usr --disable-static --enable-posix-api=yes
make -j$(nproc)
make check

make DESTDIR="$OUTPUT_DIR" install
