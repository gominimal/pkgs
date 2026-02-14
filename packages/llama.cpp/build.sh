#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake -B build
cmake --build build --config Release -j $(nproc)

mkdir -pv $OUTPUT_DIR/usr/{bin,lib}

install -vm755 build/bin/*.so $OUTPUT_DIR/usr/lib/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
