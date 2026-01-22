#!/bin/sh
set -e

sed -i 's/sighandler interrupt_signal/__sighandler_t interrupt_signal/' src/time.c

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)

make DESTDIR=$OUTPUT_DIR install
