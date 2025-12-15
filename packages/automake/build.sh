#!/bin/sh
set -e

tar xfo "automake-${MINIMAL_ARG_VERSION}.tar.xz"
cd "automake-${MINIMAL_ARG_VERSION}"

./configure --prefix=/usr

make -j$(nproc)
# TODO "Cannot change ownership to uid 1000, gid 1000"
# make -j$(($(nproc)>4?$(nproc):4)) check
make DESTDIR=$OUTPUT_DIR install
