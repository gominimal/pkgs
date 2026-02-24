#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
export OPENSSL_NO_VENDOR="1"

cargo build --release

install -D -m 0755 target/release/gurk "$OUTPUT_DIR/usr/bin/gurk"
