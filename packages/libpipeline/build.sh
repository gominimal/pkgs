#!/bin/sh
set -ex

tar xf libpipeline-1.5.8.tar.gz
cd libpipeline-1.5.8

./configure  --prefix=/usr     \
             --disable-static

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
