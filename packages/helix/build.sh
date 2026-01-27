#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
export HELIX_DEFAULT_RUNTIME=/usr/lib/helix/runtime

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/hx $OUTPUT_DIR/usr/bin/hx

mkdir -p $OUTPUT_DIR/usr/lib/helix
rm -rf runtime/grammars/sources
cp -r runtime $OUTPUT_DIR/usr/lib/helix/runtime
