#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Hermetic build path: when /cargo-vendor exists (mounted by a SLSA-grade
# builder that has pre-staged every crate from Cargo.lock as a sha-verified
# vendor tree), redirect crates.io to it and build offline. Otherwise fall
# back to the normal online build for dev iteration. Matches probe-rs's
# build.sh pattern verbatim.
if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    export BTM_GENERATE=true
    cargo build --offline --frozen --release
else
    export BTM_GENERATE=true
    cargo build --release
fi

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/btm $OUTPUT_DIR/usr/bin
install -D -m 0755 target/tmp/bottom/completion/btm.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/btm"
