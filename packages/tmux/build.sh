#!/bin/sh
set -e

sh autogen.sh
./configure --prefix=/usr --disable-static
make -j$(nproc)
# make check

make DESTDIR="$OUTPUT_DIR" install
