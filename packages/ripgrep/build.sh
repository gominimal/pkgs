#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/rg $OUTPUT_DIR/usr/bin

mkdir -p $OUTPUT_DIR/usr/share/bash-completion/completions
target/release/rg --generate complete-bash > $OUTPUT_DIR/usr/share/bash-completion/completions/rg
