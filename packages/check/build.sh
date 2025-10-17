#!/bin/sh
set -ex

tar xf check-0.15.2.tar.gz
cd check-0.15.2

autoreconf --install
./configure  --prefix=/usr     \
             --disable-static

make -j$(nproc)
make -j$(nproc) check
DESTDIR=$OUTPUT_DIR make -j$(nproc) install

# ldconfig
