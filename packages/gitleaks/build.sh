#!/bin/sh
# Imported from Wolfi `gitleaks` (8.30.1, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
# Version var lives in the `version` package and the module path kept the
# original `zricethezav` org (per upstream .goreleaser.yml) despite the GitHub
# org rename to gitleaks/gitleaks — a wrong path is silently ignored by the linker.
go build -trimpath -ldflags "-buildid= -w -s -X github.com/zricethezav/gitleaks/v8/version.Version=${MINIMAL_ARG_VERSION}" -o "$OUTPUT_DIR/usr/bin/gitleaks" .

# Shell completions, generated from the just-built binary via cobra's standard
# `completion <shell>` command. Best-effort: a file is written only when the
# command succeeds AND its output is non-empty, so a tool that lacks the command
# ships nothing rather than an empty (glob-matching, useless) file. Cobra's
# completion output is generated from the command tree — deterministic, no
# network or config — and the sandbox runs the binary on its native arch.
gen_completion() {
  # $1 = shell, $2 = dest path under $OUTPUT_DIR
  _out=$("$OUTPUT_DIR/usr/bin/gitleaks" completion "$1" 2>/dev/null) || return 0
  [ -n "$_out" ] || return 0
  install -d "$OUTPUT_DIR/$(dirname "$2")"
  printf '%s\n' "$_out" > "$OUTPUT_DIR/$2"
}
gen_completion bash usr/share/bash-completion/completions/gitleaks
gen_completion zsh  usr/share/zsh/site-functions/_gitleaks
gen_completion fish usr/share/fish/vendor_completions.d/gitleaks.fish
