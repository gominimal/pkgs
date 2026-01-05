#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

export BTM_GENERATE=true
cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/btm $OUTPUT_DIR/usr/bin
install -D -m 0755 target/tmp/bottom/completion/btm.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/btm"
