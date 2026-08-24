#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# --locked: upstream ships a Cargo.lock, so pin to it rather than re-resolving.
cargo build --release --locked

# The release profile already sets lto/codegen-units=1/strip, so no extra
# determinism flags are needed beyond the path remapping above.
install -D -m 0755 target/release/drift "$OUTPUT_DIR/usr/bin/drift"
