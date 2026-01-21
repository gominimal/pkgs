#!/bin/sh
set -e

./configure --prefix=/usr

make -j$(nproc)
# make check # TODO: Super slow so move to its own 'test' build or something
make DESTDIR=$OUTPUT_DIR install
