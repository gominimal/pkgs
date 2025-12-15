#!/bin/sh
set -e

./configure --prefix="/usr" \
            --disable-static \
            --docdir="/usr/share/doc/expat-2.7.1"

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
