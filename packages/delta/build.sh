#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

RUSTONIG_DYNAMIC_LIBONIG=1 cargo build --release

install -D -m 0755 target/release/delta $OUTPUT_DIR/usr/bin/delta
install -D -m 0755 etc/completion/completion.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/delta"

# zsh + fish completions (gominimal/inbox#470). Upstream ships all three at
# etc/completion/ (completion.bash, completion.fish, completion.zsh); only bash
# was installed. Upstream's names are generic, so they are renamed to the
# command on install.
install -D -m 0644 etc/completion/completion.fish "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/delta.fish"
install -D -m 0644 etc/completion/completion.zsh  "$OUTPUT_DIR/usr/share/zsh/site-functions/_delta"
[ -s "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/delta.fish" ]
[ -s "$OUTPUT_DIR/usr/share/zsh/site-functions/_delta" ]
head -1 "$OUTPUT_DIR/usr/share/zsh/site-functions/_delta" | grep -qx '#compdef delta'
grep -q 'complete -c' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/delta.fish"
