#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1"

cargo build --release --locked --bin wasm-bindgen

mkdir -p "$OUTPUT_DIR/usr/bin"
cp target/release/wasm-bindgen "$OUTPUT_DIR/usr/bin/"
