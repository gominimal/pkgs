#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

# OBI (OpenTelemetry eBPF Instrumentation, the donated Grafana Beyla) is
# compiled INTO otelcol-contrib as of 0.157.0: the contrib manifest declares
# `go.opentelemetry.io/obi` as a component AND carries
#   replaces: go.opentelemetry.io/obi => ../../../internal/obi-src
# That directory is NOT in the upstream repo — upstream materializes it with
# scripts/prepare-obi.sh, which curls the "source-generated" tarball (it ships
# pre-generated BPF objects, so no clang/bpf2go/Docker toolchain is needed).
# We declare that same tarball as a checksummed Source in build.ncl (repo
# convention: every input pinned by sha256) and stage it here instead of
# fetching at build time. Globbed so the version lives in ONE place (build.ncl).
mkdir -p internal/obi-src
tar -xof obi-*-source-generated.tar.gz -C internal/obi-src --strip-components=1

# Install the OpenTelemetry Collector Builder (ocb). This pin MUST track the
# distribution version: a mismatched builder resolves otelcol/service at its own
# version while the manifest pulls the rest at %{version}, which fails to build.
# Keeping it byte-equal to the package version is also what lets pkgmgr's
# build.sh version rewrite carry it forward on the next bump (the old
# `v0.150.0` pin never matched the `0.150.1` package version, so it silently
# stayed behind).
go install -trimpath go.opentelemetry.io/collector/cmd/builder@v0.159.0
OCB=$(go env GOPATH)/bin/builder

# Run ocb FROM the distribution directory. The manifest's `output_path: ./_build`
# is CWD-relative, and the obi replace path (`../../../internal/obi-src`) is
# resolved from that output dir — so ocb must run where upstream runs it
# (distributions/otelcol-contrib), making _build/../../../ == the source root.
# Running at the source root put _build at <root>/_build, so ../../../ escaped
# above it and go reported:
#   reading /internal/obi-src/go.mod: no such file or directory
cd distributions/otelcol-contrib

# go 1.27 bridge: the contrib 0.159.0 manifest resolves cockroachdb/swiss (via
# pebbletailstorageextension -> pebble/v2) at a pin whose runtime go:linkname shims are
# version-gated `!go1.27` -> `undefined: hashFn/getRuntimeHasher/fastrand64` under the go
# 1.27.0 toolchain. Upstream swiss fixed the guard 2026-08-20 (runtime_go1.20.go now reads
# `(go1.20 && !go1.28) || untested_go_version` — verified in the module zip); pin it via the
# manifest's own replaces mechanism (upstream already uses one for obi). DROP on the next
# contrib bump if its transitive pin has moved past 2026-08-20 (the greps fail loudly).
grep -q '^replaces:' manifest.yaml
grep -q 'cockroachdb/swiss' manifest.yaml && { echo "swiss already replaced/pinned in manifest — drop this patch"; exit 1; }
sed -i '/^replaces:/a\  - github.com/cockroachdb/swiss => github.com/cockroachdb/swiss v0.0.0-20260820225851-333444432258' manifest.yaml
grep -q 'cockroachdb/swiss => ' manifest.yaml

$OCB --config=manifest.yaml

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 _build/otelcol-contrib $OUTPUT_DIR/usr/bin/otelcol-contrib
