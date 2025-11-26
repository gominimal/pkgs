#!/bin/sh
set -e

cd "diffutils-${MINIMAL_ARG_VERSION}"

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install-strip
