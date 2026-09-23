#!/bin/sh
# Imported from Wolfi `git-lfs` (3.8.0, go) by pkgmgr import wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s" -o "$OUTPUT_DIR/usr/bin/git-lfs" .

# Shell completions (cobra), generated from the built binary.
gen_completion() {
  # $1 = shell, $2 = dest path under $OUTPUT_DIR
  _out=$("$OUTPUT_DIR/usr/bin/git-lfs" completion "$1" 2>/dev/null) || return 0
  [ -n "$_out" ] || return 0
  install -d "$OUTPUT_DIR/$(dirname "$2")"
  printf '%s\n' "$_out" > "$OUTPUT_DIR/$2"
}
gen_completion bash usr/share/bash-completion/completions/git-lfs
gen_completion zsh  usr/share/zsh/site-functions/_git-lfs
gen_completion fish usr/share/fish/vendor_completions.d/git-lfs.fish
