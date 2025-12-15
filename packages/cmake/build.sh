#!/bin/sh
set -e

mkdir -v build
cd build

../bootstrap --prefix=/usr

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
