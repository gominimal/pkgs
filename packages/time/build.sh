#!/bin/sh
set -e

sed -i 's/sighandler interrupt_signal/__sighandler_t interrupt_signal/' src/time.c
./configure --prefix=/usr

make -j$(nproc)

make DESTDIR=$OUTPUT_DIR install
