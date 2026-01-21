#!/bin/sh
set -e

./configure --prefix="/usr"
make -j$(nproc)
# make check
make DESTDIR=$OUTPUT_DIR install
