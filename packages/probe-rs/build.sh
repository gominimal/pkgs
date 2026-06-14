#!/bin/bash
set -euo pipefail

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# Hermetic build path: when /cargo-vendor exists (mounted by a SLSA-grade
# builder that has pre-staged every crate from Cargo.lock as a sha-verified
# vendor tree), redirect crates.io to it and build offline. Otherwise fall
# back to the normal online build for dev iteration.
if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    if [ -f /cargo-vendor/.cargo-config.toml ]; then
        cp /cargo-vendor/.cargo-config.toml .cargo/config.toml
    else
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    fi
    cargo build --offline --frozen --release -p probe-rs-tools
else
    cargo build --release -p probe-rs-tools
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/probe-rs $OUTPUT_DIR/usr/bin/
cp target/release/cargo-flash $OUTPUT_DIR/usr/bin/
cp target/release/cargo-embed $OUTPUT_DIR/usr/bin/
