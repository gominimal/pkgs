#!/bin/sh
set -ex

# /usr/bin/cc does not exist in the build environment
export CC=gcc
export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

make -j$(nproc) prefix=/usr
# make check
make prefix=/usr DESTDIR=$OUTPUT_DIR install
