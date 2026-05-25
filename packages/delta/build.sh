#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

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
    RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --offline --frozen --release
else
    RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release
fi

install -D -m 0755 target/release/delta $OUTPUT_DIR/usr/bin/delta
install -D -m 0755 etc/completion/completion.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/delta"
