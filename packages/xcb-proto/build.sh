#!/bin/sh
set -e

./configure --prefix=/usr
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
