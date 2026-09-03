#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/rg $OUTPUT_DIR/usr/bin

mkdir -p $OUTPUT_DIR/usr/share/bash-completion/completions
target/release/rg --generate complete-bash > $OUTPUT_DIR/usr/share/bash-completion/completions/rg

# zsh + fish completions (gominimal/inbox#470). rg's generator takes
# `complete-<shell>`, not a bare shell name. The command is `rg`, not
# `ripgrep`, and the completion must be named for the COMMAND.
mkdir -p "$OUTPUT_DIR/usr/share/zsh/site-functions" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d"
target/release/rg --generate complete-zsh  > "$OUTPUT_DIR/usr/share/zsh/site-functions/_rg"
target/release/rg --generate complete-fish > "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/rg.fish"
[ -s "$OUTPUT_DIR/usr/share/zsh/site-functions/_rg" ]
[ -s "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/rg.fish" ]
head -1 "$OUTPUT_DIR/usr/share/zsh/site-functions/_rg" | grep -qx '#compdef rg'
grep -q '__rg' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/rg.fish"
