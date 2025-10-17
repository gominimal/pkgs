#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release

mkdir -p $OUTPUT_DIR/usr/{bin,share/bash-completion}

cp target/release/bat $OUTPUT_DIR/usr/bin
cp -rv target/release/build/bat-*/out/assets/completions/bat.bash  $OUTPUT_DIR/usr/share/bash-completion/bat
