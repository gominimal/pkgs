#!/bin/sh
set -e

export PYTHONHASHSEED=0

./configure --prefix=/usr
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
