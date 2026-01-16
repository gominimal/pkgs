#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

install -D -m 0755 target/release/procs $OUTPUT_DIR/usr/bin/procs

mkdir -p $OUTPUT_DIR/usr/share/bash-completion/completions
target/release/procs --gen-completion-out bash > $OUTPUT_DIR/usr/share/bash-completion/completions/procs
