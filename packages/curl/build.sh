#!/bin/sh
set -ex

./configure  --prefix=/usr     \
            --disable-static \
            --with-openssl   \
            --with-ca-path=/etc/ssl/certs

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
