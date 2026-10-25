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
MANIFEST=distributions/otelcol-contrib/manifest.yaml

# The staged OBI tarball must be the version the manifest asks for (the line
# upstream's prepare-obi.sh reads). build.ncl pins it separately because it does
# not follow the package version.
OBI_WANT=$(awk '/- gomod: go\.opentelemetry\.io\/obi\/collector / {print $NF; exit}' "$MANIFEST")
[ -n "$OBI_WANT" ] || { echo "ERROR: no go.opentelemetry.io/obi/collector line in $MANIFEST" >&2; exit 1; }
[ -f "obi-${OBI_WANT}-source-generated.tar.gz" ] || {
  echo "ERROR: manifest wants OBI ${OBI_WANT}; staged: $(ls obi-*-source-generated.tar.gz)." >&2
  echo "       Move obi_version + its sha256 in build.ncl to ${OBI_WANT}." >&2
  exit 1
}
mkdir -p internal/obi-src
tar -xof "obi-${OBI_WANT}-source-generated.tar.gz" -C internal/obi-src --strip-components=1

# Install the OpenTelemetry Collector Builder (ocb) at the CORE collector version
# the manifest pins (its go.opentelemetry.io/collector/* v0.x modules), not the
# package version: the releases repo can cut patch releases (0.163.2) on a core
# that stays at 0.163.0, and cmd/builder is only tagged with core. A mismatched
# builder resolves otelcol/service at its own version and fails to build, so
# derive it and require exactly one v0 core version.
BUILDER_VERSION=$(sed -n 's#^ *- gomod: go\.opentelemetry\.io/collector/[^ ]* \(v0\.[0-9][^ ]*\)$#\1#p' "$MANIFEST" | sort -u)
[ "$(printf '%s\n' "$BUILDER_VERSION" | grep -c .)" = 1 ] || {
  echo "ERROR: expected one v0 core collector version in $MANIFEST, got: $BUILDER_VERSION" >&2
  exit 1
}
go install -trimpath "go.opentelemetry.io/collector/cmd/builder@${BUILDER_VERSION}"
OCB=$(go env GOPATH)/bin/builder

# Run ocb FROM the distribution directory. The manifest's `output_path: ./_build`
# is CWD-relative, and the obi replace path (`../../../internal/obi-src`) is
# resolved from that output dir — so ocb must run where upstream runs it
# (distributions/otelcol-contrib), making _build/../../../ == the source root.
# Running at the source root put _build at <root>/_build, so ../../../ escaped
# above it and go reported:
#   reading /internal/obi-src/go.mod: no such file or directory
cd distributions/otelcol-contrib

# go 1.27 bridge: the contrib 0.159.0 manifest resolves cockroachdb/swiss (via pebble/v2) at a
# pin whose go:linkname shims are gated `!go1.27`, so it fails to compile under go 1.27
# (undefined hashFn/getRuntimeHasher/fastrand64). Pin a newer swiss whose guard reads
# `(go1.20 && !go1.28) || untested_go_version` via the manifest's own replaces list.
# Drop on the next contrib bump if the transitive pin has moved past it; the greps fail loudly.
grep -q '^replaces:' manifest.yaml
grep -q 'cockroachdb/swiss' manifest.yaml && { echo "swiss already replaced/pinned in manifest — drop this patch"; exit 1; }
sed -i '/^replaces:/a\  - github.com/cockroachdb/swiss => github.com/cockroachdb/swiss v0.0.0-20260820225851-333444432258' manifest.yaml
grep -q 'cockroachdb/swiss => ' manifest.yaml

$OCB --config=manifest.yaml

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 _build/otelcol-contrib $OUTPUT_DIR/usr/bin/otelcol-contrib
