#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/just $OUTPUT_DIR/usr/bin/just

mkdir -p $OUTPUT_DIR/usr/share/bash-completion/completions
target/release/just --completions bash > $OUTPUT_DIR/usr/share/bash-completion/completions/just

# zsh + fish completions (gominimal/inbox#470).
#
# just's bash and fish outputs are DYNAMIC one-liners, not static scripts:
#   bash -> eval "$(JUST_COMPLETE=bash just)"
#   fish -> JUST_COMPLETE=fish just | source
# Both work, because bash-completion sources files from its completions dir and
# fish sources vendor_completions.d/<cmd>.fish when completing <cmd>. Only the
# zsh output is a conventional `#compdef` file. The assertions below are
# therefore per-shell rather than the usual shared pair — do not "normalise"
# them to `complete -c` or the build will fail.
mkdir -p "$OUTPUT_DIR/usr/share/zsh/site-functions" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d"
target/release/just --completions zsh  > "$OUTPUT_DIR/usr/share/zsh/site-functions/_just"
target/release/just --completions fish > "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/just.fish"
[ -s "$OUTPUT_DIR/usr/share/zsh/site-functions/_just" ]
[ -s "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/just.fish" ]
head -1 "$OUTPUT_DIR/usr/share/zsh/site-functions/_just" | grep -qx '#compdef just'
grep -q 'JUST_COMPLETE=fish' "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/just.fish"
