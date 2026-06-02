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
    # --frozen requires the committed codex-rs/Cargo.lock to match the
    # vendored set exactly; with the git-source deps (tungstenite fork)
    # redirected to /cargo-vendor via .cargo-config.toml, cargo wants to
    # rewrite the lock's source entries, which --frozen forbids. Drop
    # --frozen: --offline alone stays hermetic (resolves purely from the
    # vendored crates, no network) and lets cargo reconcile the lock.
    cargo build --offline --release -p codex-cli
else
    cargo build --release -p codex-cli
fi

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/codex $OUTPUT_DIR/usr/bin/codex
