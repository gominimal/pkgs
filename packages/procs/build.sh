#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

install -D -m 0755 target/release/procs $OUTPUT_DIR/usr/bin/procs

mkdir -p $OUTPUT_DIR/usr/share/bash-completion/completions
target/release/procs --gen-completion-out bash > $OUTPUT_DIR/usr/share/bash-completion/completions/procs

# zsh + fish completions (gominimal/inbox#470). procs uses --gen-completion-out
# (not --completions); verified all three shells emit correct content.
mkdir -p "$OUTPUT_DIR/usr/share/zsh/site-functions" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d"
target/release/procs --gen-completion-out zsh  > "$OUTPUT_DIR/usr/share/zsh/site-functions/_procs"
target/release/procs --gen-completion-out fish > "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/procs.fish"
[ -s "$OUTPUT_DIR/usr/share/zsh/site-functions/_procs" ]
[ -s "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/procs.fish" ]
head -1 "$OUTPUT_DIR/usr/share/zsh/site-functions/_procs" | grep -qx '#compdef procs'
grep -q 'complete -c' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/procs.fish"
