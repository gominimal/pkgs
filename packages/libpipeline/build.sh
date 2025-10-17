#!/bin/sh
set -ex

tar xf libpipeline-1.5.8.tar.gz
cd libpipeline-1.5.8

./bootstrap
./configure  --prefix=/usr     \
             --disable-static

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make DESTDIR="$OUTPUT_DIR" -j$(nproc) install

