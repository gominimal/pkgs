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

# sd is a cargo workspace; the binary lives in the sd-cli member.
if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    cargo build --offline --frozen --release -p sd-cli
else
    cargo build --release -p sd-cli
fi

install -D -m 0755 target/release/sd "$OUTPUT_DIR/usr/bin/sd"

# Upstream ships pre-generated completions in gen/completions/ — use
# those rather than a `sd completions <shell>` subcommand (sd doesn't
# have one) or a runtime-generation step.
install -D -m 0644 gen/completions/sd.bash  "$OUTPUT_DIR/usr/share/bash-completion/completions/sd"
install -D -m 0644 gen/completions/sd.fish  "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/sd.fish"
install -D -m 0644 gen/completions/_sd      "$OUTPUT_DIR/usr/share/zsh/site-functions/_sd"
