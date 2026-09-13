#!/bin/sh
set -ex
export CXX=g++
export CXXFLAGS="-O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"
./configure
make -j"$(nproc)" cadical
mkdir -p "$OUTPUT_DIR/usr/bin"
cp build/cadical "$OUTPUT_DIR/usr/bin/cadical"
