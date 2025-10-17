#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release

install -D -m 0755 target/release/delta $OUTPUT_DIR/usr/bin/delta
install -D -m 0755 etc/completion/completion.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/delta"
