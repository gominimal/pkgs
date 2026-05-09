#!/bin/sh
set -ex

# Source unpacks into cwd via `extract = true` + `strip_prefix` in
# build.ncl — no explicit `cd` needed (mirrors delta/codex pattern).

export CC=gcc
export LD=gcc
# `--remap-path-prefix` strips absolute build-time paths from the
# binary so reruns are byte-identical regardless of build directory
# or `$HOME`. Two mappings: source dir (where the tarball extracted)
# and the cargo registry (where transitive dependency source lives).
# `CARGO_INCREMENTAL=0` disables incremental compilation, which would
# otherwise cache build state in non-deterministic ways. Both per
# gominimal/minimal-repro's reproducibility-fixes guide.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0

cargo build --release

install -D -m 0755 target/release/starship "$OUTPUT_DIR/usr/bin/starship"

# Emit shell completions via the just-built binary.
"$OUTPUT_DIR/usr/bin/starship" completions bash > /tmp/starship.bash
"$OUTPUT_DIR/usr/bin/starship" completions fish > /tmp/starship.fish
"$OUTPUT_DIR/usr/bin/starship" completions zsh  > /tmp/_starship

install -D -m 0644 /tmp/starship.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/starship"
install -D -m 0644 /tmp/starship.fish "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/starship.fish"
install -D -m 0644 /tmp/_starship     "$OUTPUT_DIR/usr/share/zsh/site-functions/_starship"
