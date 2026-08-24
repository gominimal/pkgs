#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# 0.9.2 restructured the repo into a Cargo workspace: the old standalone
# `daemon/` crate is now the `crates/teamtype` member. Build the `teamtype` bin
# by name from the workspace root (robust to the layout change) rather than
# `cd`-ing into a hardcoded subdir. The workspace `target/` is at the root.
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
    cargo build --offline --frozen --release --bin teamtype
else
    cargo build --release --bin teamtype
fi

install -D -m 0755 target/release/teamtype "$OUTPUT_DIR/usr/bin/teamtype"
