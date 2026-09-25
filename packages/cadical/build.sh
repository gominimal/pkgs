#!/bin/sh
set -ex
export CXX=g++
export CXXFLAGS="-O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"
# Reproducibility: 2.1.2's make-build-header.sh embeds `date` and
# `uname -srmn` (build wall-clock + host kernel/hostname) into build.hpp.
# Pin both before make regenerates the header from the script.
sed -i \
  -e 's/^DATE=.*/DATE="1970-01-01 00:00:00 UTC"/' \
  -e 's/^OS=.*/OS="Linux"/' \
  scripts/make-build-header.sh
./configure
make -j"$(nproc)" cadical
mkdir -p "$OUTPUT_DIR/usr/bin"
cp build/cadical "$OUTPUT_DIR/usr/bin/cadical"
