#!/bin/sh
set -ex

# Source unpacks into cwd via `extract = true` + `strip_prefix` in
# build.ncl — no explicit `cd` needed.

export GOROOT=/usr/go
# Static binary so the result has no glibc-version coupling beyond
# what the runtime_dep declares; matches kubectl's choice.
export CGO_ENABLED=0
# Reproducibility: strip absolute build paths and skip embedding
# git VCS metadata — per gominimal/minimal-repro's
# reproducibility-fixes guide.
export GOFLAGS="-trimpath -buildvcs=false"
# Skip the public sum DB check; sandbox doesn't have outbound to
# sum.golang.org. Module checksums in go.sum are still verified.
export GONOSUMCHECK=*
export GONOSUMDB=*
# Universal env hygiene from the same guide — deterministic locale
# + UTC for any date strings the build emits.
export LC_ALL=C
export TZ=UTC

# `-buildid=` clears Go's content-derived build ID stamp; combined
# with `-trimpath` above this is the canonical "deterministic Go
# binary" recipe. `-w -s` strips DWARF + symbol tables (smaller
# binary, no source-path leaks). The `-X` flag injects the
# upstream version string into k9s's `cmd.version` package
# variable (declared at cmd/root.go:36) so `k9s version` reports
# the right number instead of the "dev" default.
go build \
  -ldflags "-buildid= -w -s -X github.com/derailed/k9s/cmd.version=v${MINIMAL_ARG_VERSION}" \
  -o k9s

install -D -m 0755 k9s "$OUTPUT_DIR/usr/bin/k9s"
