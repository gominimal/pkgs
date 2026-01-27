#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
export OPENSSL_DIR=/usr
export OPENSSL_NO_VENDOR=1

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/zellij $OUTPUT_DIR/usr/bin/zellij
