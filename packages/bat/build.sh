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
    RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --offline --frozen --release
else
    RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release
fi

install -D -m 0755 target/release/bat $OUTPUT_DIR/usr/bin/bat
install -D -m 0755 target/release/build/bat-*/out/assets/completions/bat.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/bat"
