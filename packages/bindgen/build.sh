#!/bin/sh
set -ex

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# The workspace's CLI crate; the library crate is what other projects
# vendor themselves.
cargo build --release -p bindgen-cli

install -D -m 0755 target/release/bindgen "$OUTPUT_DIR/usr/bin/bindgen"
