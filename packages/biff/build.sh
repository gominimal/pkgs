#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

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
    cargo build --offline --frozen --release
else
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
# Upstream renamed the crate/binary biff -> bttf (BurntSushi/biff -> bttf), so
# cargo now emits target/release/bttf. Install it under the package's `biff`
# command name (the output glob is usr/bin/biff).
cp target/release/bttf $OUTPUT_DIR/usr/bin/biff
