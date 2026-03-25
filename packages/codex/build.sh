#!/bin/bash
set -euo pipefail

cd codex-rs

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Needed for crates that use bindgen / libclang
export LIBCLANG_PATH="$(dirname $(find /usr/lib -name 'libclang*.so' | head -1))"

cargo build --release -p codex-cli

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/codex $OUTPUT_DIR/usr/bin/codex
