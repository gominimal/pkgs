#!/bin/sh
set -e

tar xf autoconf-2.72.tar.xz
cd autoconf-2.72

./configure --prefix=/usr

make -j$(nproc)
# make check # TODO: Super slow so move to its own 'test' build or something
make DESTDIR=$OUTPUT_DIR install
