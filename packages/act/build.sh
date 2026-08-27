#!/bin/sh
# Imported from Wolfi `act` (0.2.89, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
# Stamp the version so `act --version` reports it (act reads `main.version`);
# $MINIMAL_ARG_VERSION is forwarded from build.ncl's `version` via build_args.
go build -trimpath -ldflags "-buildid= -w -s -X main.version=${MINIMAL_ARG_VERSION}" -o act .
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 act "$OUTPUT_DIR/usr/bin/act"

# Shell completions (cobra), generated from the built binary. Best-effort:
# written only on success and non-empty output, so nothing ships if the command
# is absent. `|| return 0` never breaks the build. (Backfill of the automatic
# importer behaviour — pkgmgr-rs#745.)
gen_completion() {
  _out=$("$OUTPUT_DIR/usr/bin/act" completion "$1" 2>/dev/null) || return 0
  [ -n "$_out" ] || return 0
  install -d "$OUTPUT_DIR/$(dirname "$2")"
  printf '%s\n' "$_out" > "$OUTPUT_DIR/$2"
}
gen_completion bash usr/share/bash-completion/completions/act
gen_completion zsh  usr/share/zsh/site-functions/_act
gen_completion fish usr/share/fish/vendor_completions.d/act.fish
