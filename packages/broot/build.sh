#!/usr/bin/env bash
set -euo pipefail

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
    if [ -f /cargo-vendor/Cargo.lock ] && [ ! -f Cargo.lock ]; then
        cp /cargo-vendor/Cargo.lock Cargo.lock
    fi
    cargo build --offline --frozen --release
else
    cargo build --release
fi

install -D -m 0755 target/release/broot "$OUTPUT_DIR/usr/bin/broot"

# build.rs emits shell completions into OUT_DIR; copy them out
completion_dir=$(find target/release/build -path '*/out/broot.bash' -printf '%h\n' | head -n1)
if [[ -n "$completion_dir" ]]; then
  install -D -m 0644 "$completion_dir/broot.bash" "$OUTPUT_DIR/usr/share/bash-completion/completions/broot"
  install -D -m 0644 "$completion_dir/broot.fish" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/broot.fish"
  install -D -m 0644 "$completion_dir/_broot"     "$OUTPUT_DIR/usr/share/zsh/site-functions/_broot"
fi
