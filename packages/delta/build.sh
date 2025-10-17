#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release

mkdir -p $OUTPUT_DIR/usr/{bin,share/bash-completion}

cp target/release/delta $OUTPUT_DIR/usr/bin
cp -rv etc/completion/completion.bash  $OUTPUT_DIR/usr/share/bash-completion/delta
