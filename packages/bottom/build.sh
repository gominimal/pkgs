#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

export BTM_GENERATE=true
cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/btm $OUTPUT_DIR/usr/bin
install -D -m 0755 target/tmp/bottom/completion/btm.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/btm"

# zsh + fish completions (gominimal/inbox#470). bottom's build.rs generates
# bash, zsh, fish (and 4 more) into target/tmp/bottom/completion/ on every
# build via clap_complete; only bash was being installed, and the outputs glob
# only covered bash, so the rest were discarded twice over.
# clap_complete names the zsh file `_btm` already — the command is `btm`, not
# `bottom`, and the completion must be named for the COMMAND.
C=target/tmp/bottom/completion
install -D -m 0644 "$C/_btm"     "$OUTPUT_DIR/usr/share/zsh/site-functions/_btm"
install -D -m 0644 "$C/btm.fish" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/btm.fish"
[ -s "$OUTPUT_DIR/usr/share/zsh/site-functions/_btm" ]
[ -s "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/btm.fish" ]
head -1 "$OUTPUT_DIR/usr/share/zsh/site-functions/_btm" | grep -qx '#compdef btm'
grep -q 'complete -c' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/btm.fish"
