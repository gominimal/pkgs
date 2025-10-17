#!/bin/sh
set -e

tar xf groff-1.23.0.tar.gz
cd groff-1.23.0

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR="$OUTPUT_DIR" install
