#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

if [ -d /cargo-vendor ]; then
    # macOS AppleDouble files (._*) get embedded when the vendor tarball
    # is created on a Mac. They break libgit2-sys's build.rs which tries
    # to compile them as C (gcc errors on "._realpath.c" etc).
    # Cheap fix: strip them before cargo starts. Long-term: re-vendor with
    # COPYFILE_DISABLE=1 on the staging host (see orch task #91/#93).
    find /cargo-vendor -name '._*' -delete 2>/dev/null || true
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

install -D -m 0755 target/release/bat $OUTPUT_DIR/usr/bin/bat
install -D -m 0755 target/release/build/bat-*/out/assets/completions/bat.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/bat"
