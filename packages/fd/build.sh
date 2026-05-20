#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    cargo build --offline --frozen --release --no-default-features
else
    cargo build --release --no-default-features
fi

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/fd $OUTPUT_DIR/usr/bin/fd
