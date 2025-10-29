#!/bin/sh
set -e

./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
