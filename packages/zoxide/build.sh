#!/bin/sh
set -ex

# Source unpacks into cwd via `extract = true` + `strip_prefix` in
# build.ncl — no explicit `cd` needed.

export CC=gcc
export LD=gcc
# Reproducibility: strip absolute build-time paths from the binary
# (source dir AND cargo registry where dep source lives) plus
# disable incremental compilation. Per gominimal/minimal-repro's
# reproducibility-fixes guide.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0

if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    cargo build --offline --frozen --release
else
    cargo build --release
fi

install -D -m 0755 target/release/zoxide "$OUTPUT_DIR/usr/bin/zoxide"

# Upstream ships pre-generated completions in contrib/completions/ —
# install directly rather than generating at build time (zoxide's
# `init` subcommand is for shell-prompt integration, not completion
# emission).
install -D -m 0644 contrib/completions/zoxide.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/zoxide"
install -D -m 0644 contrib/completions/zoxide.fish "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/zoxide.fish"
install -D -m 0644 contrib/completions/_zoxide     "$OUTPUT_DIR/usr/share/zsh/site-functions/_zoxide"
