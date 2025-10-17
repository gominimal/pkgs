#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release

install -D -m 0755 target/release/bat $OUTPUT_DIR/usr/bin/bat
install -D -m 0755 target/release/build/bat-*/out/assets/completions/bat.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/bat"
