#!/bin/sh
set -e

./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs       \
            --docdir=/usr/share/doc/fontconfig-2.17.1

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
