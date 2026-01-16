#!/bin/sh
set -e

cmake -B build
cmake --build build --config Release -j $(nproc)

mkdir -pv $OUTPUT_DIR/usr/{bin,lib}

install -vm755 build/bin/*.so $OUTPUT_DIR/usr/lib/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
