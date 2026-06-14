#!/usr/bin/env bash
set -euo pipefail

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export HELIX_DEFAULT_RUNTIME=/usr/lib/helix/runtime
export HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1

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
    cargo build --offline --frozen --release --locked
else
    cargo build --release --locked
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 target/release/hx "$OUTPUT_DIR/usr/bin/hx"

mkdir -p "$OUTPUT_DIR/usr/lib/helix"
rm -rf runtime/grammars/sources
cp -r runtime "$OUTPUT_DIR/usr/lib/helix/runtime"
