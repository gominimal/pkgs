#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  ZIGARCH=x86_64 ;;
  aarch64) ZIGARCH=aarch64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tar -xof "zig-${ZIGARCH}-linux-${MINIMAL_ARG_VERSION}.tar.xz"
cd "zig-${ZIGARCH}-linux-${MINIMAL_ARG_VERSION}"

mkdir -p $OUTPUT_DIR/usr/{bin,lib/zig,share/doc/zig}

install -m 755 zig $OUTPUT_DIR/usr/bin/zig
cp -r lib/* $OUTPUT_DIR/usr/lib/zig/
cp -r doc/* $OUTPUT_DIR/usr/share/doc/zig/
