#!/usr/bin/env bash
set -euo pipefail

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"

# build.rs writes the shell completions into its OUT_DIR, which lives in cargo's build-dir. That
# layout is internal and changed in cargo 1.100 (build/broot-<hash>/out became
# build/broot/<hash>/out), so take OUT_DIR from cargo's build-script-executed JSON message, the
# interface cargo's changelog points tools at. Rendered diagnostics still go to stderr.
cargo build --release --message-format=json-render-diagnostics > cargo-messages.jsonl

install -D -m 0755 target/release/broot "$OUTPUT_DIR/usr/bin/broot"

completion_dir=$(grep '"reason":"build-script-executed"' cargo-messages.jsonl \
  | grep '"package_id":"[^"]*broot[@# ]' | grep -o '"out_dir":"[^"]*"' \
  | sed 's/^"out_dir":"//; s/"$//' | head -n1 || true)
# The outputs below declare all three files: fail here, with the reason, rather than ship none.
[[ -n "$completion_dir" && -f "$completion_dir/broot.bash" ]] || {
  echo "broot: FATAL no completions; build-script out_dir='${completion_dir}'" >&2
  exit 1
}
install -D -m 0644 "$completion_dir/broot.bash" "$OUTPUT_DIR/usr/share/bash-completion/completions/broot"
install -D -m 0644 "$completion_dir/broot.fish" "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/broot.fish"
install -D -m 0644 "$completion_dir/_broot"     "$OUTPUT_DIR/usr/share/zsh/site-functions/_broot"
