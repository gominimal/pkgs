#!/bin/sh
set -e

tar xfo "icu4c-${MINIMAL_ARG_VERSION}-sources.tgz"
cd icu/source

./configure --prefix=/usr

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
