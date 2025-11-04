#!/bin/sh
set -ex

tar xf "zstd-${MINIMAL_ARG_VERSION}.tar.gz"
cd "zstd-${MINIMAL_ARG_VERSION}"

# /usr/bin/cc does not exist in the build environment
export CC=gcc

make -j$(nproc) prefix=/usr
make check
make prefix=/usr DESTDIR=$OUTPUT_DIR install
