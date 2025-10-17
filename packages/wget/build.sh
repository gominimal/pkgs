#!/bin/sh
set -e

./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
