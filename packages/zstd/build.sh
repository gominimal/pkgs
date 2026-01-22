#!/bin/sh
set -ex

# /usr/bin/cc does not exist in the build environment
export CC=gcc

make -j$(nproc) prefix=/usr
# make check
make prefix=/usr DESTDIR=$OUTPUT_DIR install
