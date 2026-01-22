#!/bin/sh
set -ex

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --with-openssl      \
            --with-ca-path=/etc/ssl/certs

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
