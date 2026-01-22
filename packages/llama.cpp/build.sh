#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake -B build
cmake --build build --config Release -j $(nproc)

mkdir -pv $OUTPUT_DIR/usr/{bin,lib}

install -vm755 build/bin/*.so $OUTPUT_DIR/usr/lib/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
