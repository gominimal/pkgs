#!/bin/sh
set -e

tar xf "groff-${MINIMAL_ARG_VERSION}.tar.gz"
cd "groff-${MINIMAL_ARG_VERSION}"

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR="$OUTPUT_DIR" install
