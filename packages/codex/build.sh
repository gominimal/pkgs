#!/bin/bash
set -euo pipefail

cd codex-rs

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Needed for crates that use bindgen / libclang
export LIBCLANG_PATH="$(dirname $(find /usr/lib -name 'libclang*.so' | head -1))"

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
    cargo build --offline --frozen --release -p codex-cli
else
    cargo build --release -p codex-cli
fi

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/codex $OUTPUT_DIR/usr/bin/codex
