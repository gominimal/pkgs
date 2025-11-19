#!/bin/sh
set -e


./configure --prefix=/usr

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
