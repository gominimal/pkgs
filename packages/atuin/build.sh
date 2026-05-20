#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    cargo build --offline --frozen --release --bin atuin
else
    cargo build --release --bin atuin
fi

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/atuin $OUTPUT_DIR/usr/bin/atuin
