#!/bin/sh
set -eu
export GOROOT=/usr/go

# CGO_ENABLED=0 is upstream's own build setting (see fq's Makefile) and is what
# makes the result a pure-Go static binary with no DT_NEEDED — hence the empty
# runtime_deps in build.ncl. Flipping this back on would silently add a libc
# dependency that nothing here declares.
export CGO_ENABLED=0

# Reproducibility (see AGENTS.md): -trimpath strips the build directory out of
# recorded paths and -buildid= clears the non-deterministic build ID. -s -w
# drop the symbol and DWARF tables, matching the other Go packages here.
#
# No -X version stamping: fq keeps its version as a plain const in fq.go, so
# `fq --version` already reports 0.17.0 from the source tree. A -ldflags -X
# aimed at a const would be silently ignored — the linker only rewrites vars.
go build -trimpath -ldflags "-buildid= -s -w" -o fq .

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 fq "$OUTPUT_DIR/usr/bin/fq"
