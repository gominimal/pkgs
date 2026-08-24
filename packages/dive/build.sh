#!/bin/sh
# Imported from Wolfi `dive` (0.13.1, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s -X main.version=v${MINIMAL_ARG_VERSION}" -o "$OUTPUT_DIR/usr/bin/dive" .

# Shell completions (cobra), generated from the built binary. Best-effort:
# written only on success and non-empty output, so nothing ships if the command
# is absent. `|| return 0` never breaks the build. (Backfill of the automatic
# importer behaviour — pkgmgr-rs#745.)
gen_completion() {
  _out=$("$OUTPUT_DIR/usr/bin/dive" completion "$1" 2>/dev/null) || return 0
  [ -n "$_out" ] || return 0
  install -d "$OUTPUT_DIR/$(dirname "$2")"
  printf '%s\n' "$_out" > "$OUTPUT_DIR/$2"
}
gen_completion bash usr/share/bash-completion/completions/dive
gen_completion zsh  usr/share/zsh/site-functions/_dive
gen_completion fish usr/share/fish/vendor_completions.d/dive.fish
