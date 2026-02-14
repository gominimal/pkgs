#!/bin/sh
set -ex

tar xf "zig-x86_64-linux-${MINIMAL_ARG_VERSION}.tar.xz"
cd "zig-x86_64-linux-${MINIMAL_ARG_VERSION}"

mkdir -p $OUTPUT_DIR/usr/{bin,lib/zig,share/doc/zig}

install -m 755 zig $OUTPUT_DIR/usr/bin/zig
cp -r lib/* $OUTPUT_DIR/usr/lib/zig/
cp -r doc/* $OUTPUT_DIR/usr/share/doc/zig/
