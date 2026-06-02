#!/usr/bin/env bash
set -euo pipefail

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

cargo build --release

install -D -m 0755 target/release/broot "$OUTPUT_DIR/usr/bin/broot"

# build.rs emits shell completions into OUT_DIR; copy them out
completion_dir=$(find target/release/build -path '*/out/broot.bash' -printf '%h\n' | head -n1)
if [[ -n "$completion_dir" ]]; then
  install -D -m 0644 "$completion_dir/broot.bash" "$OUTPUT_DIR/usr/share/bash-completion/completions/broot"
  install -D -m 0644 "$completion_dir/broot.fish" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/broot.fish"
  install -D -m 0644 "$completion_dir/_broot"     "$OUTPUT_DIR/usr/share/zsh/site-functions/_broot"
fi
