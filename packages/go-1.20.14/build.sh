#!/bin/sh
# ============================================================================================
# build.sh — go-1.20.14: the FIRST self-hosted rung of the Go ladder (issue #19).
#
#   IS:     /usr/lib/go-1.20.14 — a Go 1.17.13 toolchain built BY go-1.17.13.
#           go1.20.14 is self-hosted (dist in Go), so it REQUIRES a working Go
#           to build — which is exactly why the go-1.4-from-C rung below it had to exist.
#   IS NOT: the shipped Go.  1.17.13 is the minimum bootstrap for Go 1.20, so the ladder continues
#           go-1.20.14 -> go-1.20.14 -> go-1.22.6 -> go-1.24.x -> go.
#
# Chain: hex0 -> ... -> gcc-15.2.0-glibc -> go-1.4 (C only) -> THIS.
#
# ── LESSONS CARRIED FROM go-1.4's FIRST GREEN (do not regress these) ─────────────────────────
#  1. NO findutils in the sandbox — only declared build_deps exist.  Never use `find`; the
#     archives are sha-PINNED so their layout is fixed and knowable.  Assert, don't discover.
#  2. TMPDIR is REQUIRED — Go's dist falls back to a hardcoded /var/tmp, which does not exist here.
#  3. build.sh must be mode 755 (the sandbox execs it directly; 644 => EACCES).
#  4. GOROOT_BOOTSTRAP must be WRITABLE — the hydrated build_dep prefix is READ-ONLY, and go1.4's
#     `go build` (pre-build-cache) writes compiled packages into its own GOROOT/pkg.  This is the
#     same class as the rust ladder's read-only-stage0 wall, pre-empted here with a writable copy.
# ============================================================================================
set -ex

# ── STALE-STATE GUARD (2026-09-01): buildbot's res-server persists /build across rounds; a
# failed round's partial install in $OUTPUT_DIR would be swallowed by the capture globs.
# Start from an EMPTY output (build trees stay warm for the incremental ratchet).
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"
VERSION="${MINIMAL_ARG_VERSION:-1.20.14}"
SRC_TARBALL="go${VERSION}.src.tar.gz"
SRC_SHA=1aef321a0e3e38b7e91d2d7eb64040666cabdcc77d383de3c9522d0d69b67f4e
BUILDROOT="$(pwd)"
PREFIX_REL="usr/lib/go-${VERSION}"
BOOTSTRAP_PREFIX=/usr/lib/go-1.17.13   # the predecessor rung (a build_dep of this rung)
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

# ============================================================================================
# P0 — PRECONDITIONS.  Assert BOTH anchors: the seed-rooted gcc AND the C-rooted go-1.4.
# ============================================================================================
BGCC="$(command -v gcc || true)"
[ -n "${BGCC}" ] || { echo "go-1.20.14 infra: B5 gcc not on PATH" >&2; exit 1; }
for t in as ld ar ranlib make sed grep tar bash uname sha256sum cp mkdir; do
  command -v "$t" >/dev/null 2>&1 || { echo "go-1.20.14 infra: '$t' not on PATH" >&2; exit 1; }
done
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || {
  echo "go-1.20.14 infra: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}' (B5)" >&2; exit 1; }
[ -x "${BOOTSTRAP_PREFIX}/bin/go" ] || {
  echo "go-1.20.14 infra: predecessor go-1.17.13 is missing at ${BOOTSTRAP_PREFIX}/bin/go — that rung IS the anchor" >&2
  exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "go-1.20.14 infra: B4 sysroot missing at ${SR}" >&2; exit 1; }
[ -f "${SRC_TARBALL}" ]    || { echo "go-1.20.14 infra: source ${SRC_TARBALL} absent" >&2; exit 1; }
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || {
  echo "go-1.20.14 infra: source sha mismatch — refusing to build unpinned" >&2; exit 1; }

# ============================================================================================
# P1 — WRITABLE GOROOT_BOOTSTRAP (lesson 4).  The hydrated go-1.4 prefix is read-only; go1.4's
# `go build` has no build cache and writes objects under its own GOROOT/pkg.  Copy it writable.
# ============================================================================================
BOOT="${BUILDROOT}/boot-go"
cp -a "${BOOTSTRAP_PREFIX}" "${BOOT}"
[ -x "${BOOT}/bin/go" ] || { echo "go-1.20.14 infra: writable go-1.17.13 copy has no bin/go" >&2; exit 1; }
# Prove the anchor RUNS before relying on it (it was built for GOROOT_FINAL=/usr/lib/go-1.4, so a
# bare invocation without GOROOT set would say "cannot find GOROOT" — that is not a failure).
BOOTVER="$(GOROOT="${BOOT}" "${BOOT}/bin/go" version 2>&1 || true)"
echo "go-1.20.14: bootstrap Go = ${BOOTVER}" >&2
case "${BOOTVER}" in *go1.17.13*) : ;; *)
  echo "go-1.20.14 infra: bootstrap go version is '${BOOTVER}', expected go1.17.13 (the predecessor rung)" >&2
  exit 1 ;; esac

# ============================================================================================
# P2 — BUILD.  1.17's make.bash runs $GOROOT_BOOTSTRAP/bin/go to compile cmd/dist, then dist
# builds the real toolchain.  CGO_ENABLED=0 keeps the host libc/headers out of the bootstrap.
# ============================================================================================
tar --no-same-owner -xzf "${SRC_TARBALL}"
# sha-pinned layout: the official go source archives unpack to ./go
GODIR=go
[ -d "${GODIR}/src" ] || { echo "go-1.20.14 infra: expected ./go/src after untar. cwd:" >&2; ls -la >&2; exit 1; }
# This rung must be SELF-HOSTED (dist in Go) — that is what makes go-1.4 load-bearing.
NG=0; for f in "${GODIR}"/src/cmd/dist/*.go; do [ -f "$f" ] && NG=$((NG+1)); done
[ "${NG}" -gt 0 ] || { echo "go-1.20.14 infra: src/cmd/dist has no .go files (${NG}) — unexpected source" >&2; exit 1; }
echo "go-1.20.14: self-hosted dist confirmed (${NG} .go files) — requires the C-rooted go-1.4" >&2

GOTMP="${BUILDROOT}/gotmp"; mkdir -p "${GOTMP}"     # lesson 2
cd "${GODIR}/src"
CGO_ENABLED=0 \
GOTOOLCHAIN=local \
TMPDIR="${GOTMP}" \
GOROOT_BOOTSTRAP="${BOOT}" \
GOROOT_FINAL="/${PREFIX_REL}" \
GOCACHE="${BUILDROOT}/gocache" \
GOPATH="${BUILDROOT}/gopath" \
GOFLAGS=-trimpath \
GOOS=linux GOARCH=amd64 GOHOSTOS=linux GOHOSTARCH=amd64 \
  ./make.bash
cd "${BUILDROOT}"

# ============================================================================================
# P3 — INSTALL the whole GOROOT (bin + pkg + src + lib): a Go toolchain compiles the stdlib
# sources of its own GOROOT, and the NEXT rung consumes this tree as GOROOT_BOOTSTRAP.
# ============================================================================================
DEST="${OUTPUT_DIR}/${PREFIX_REL}"
mkdir -p "${DEST}"
cp -a "${GODIR}/." "${DEST}/"
rm -rf "${DEST}/.git" "${DEST}/test" "${DEST}/api" 2>/dev/null || true
[ -x "${DEST}/bin/go" ] || { echo "go-1.20.14: FATAL bin/go missing after install" >&2; exit 1; }

# ============================================================================================
# FUNCTIONAL GATE — FAIL-SHUT.  Compile AND RUN, assert the computed value.  Additionally assert
# the produced toolchain reports 1.17.13 (a wrong-version toolchain would silently break the next
# rung's bootstrap-minimum requirement).
# ============================================================================================
GATE="${BUILDROOT}/gogate"; mkdir -p "${GATE}"
cat > "${GATE}/hello.go" <<'EOF'
package main

import (
	"fmt"
	"strings"
)

func main() {
	// exercise the stdlib (strings) + generics-free generic-ish code paths, not just the parser
	parts := []string{"GO", "12014", "GATE"}
	sum := 0
	for i := 1; i <= 6; i++ {
		sum += i
	}
	fmt.Printf("%s:%d\n", strings.Join(parts, "-"), sum)
}
EOF
VOUT="$(GOROOT="${DEST}" "${DEST}/bin/go" version 2>&1 || true)"
echo "go-1.20.14: produced toolchain = ${VOUT}" >&2
case "${VOUT}" in *"go${VERSION}"*) : ;; *)
  echo "go-1.20.14: FATAL produced toolchain reports '${VOUT}', expected go${VERSION}" >&2; exit 1 ;; esac
set +e
GOUT="$(cd "${GATE}" && GOROOT="${DEST}" GOTOOLCHAIN=local GOPATH="${GATE}/gp" GOCACHE="${GATE}/gc" CGO_ENABLED=0 \
  TMPDIR="${GOTMP}" timeout 300 "${DEST}/bin/go" run hello.go 2>"${GATE}/err")"
grc=$?
set -e
if [ "${GOUT}" = "GO-12014-GATE:21" ]; then
  echo "GO12014-GATE: PASS (go-1.17.13-rooted Go 1.20.14 compiled AND RAN a stdlib program; got '${GOUT}')" >&2
else
  echo "GO12014-GATE: FAIL (rc=${grc}, got '${GOUT}', want 'GO-1713-GATE:21'); tail:" >&2
  tail -20 "${GATE}/err" >&2 || true
  exit 1
fi

mkdir -p "${OUTPUT_DIR}/usr/share/go-${VERSION}"
{
  echo "go-${VERSION} (Go ladder rung 3, issue #19)"
  echo "source:       ${SRC_TARBALL}  sha256=${SRC_SHA}"
  echo "bootstrapped: ${BOOTVER}  (from ${BOOTSTRAP_PREFIX} — the C-rooted go-1.4 joint)"
  echo "built_by:     that Go; C toolchain gcc ${GCCVER} (B5, seed-rooted to hex0) available for cgo-less probes"
  echo "cgo:          disabled"
  echo "goroot_final: /${PREFIX_REL}"
  echo "gate:         compiled+ran a stdlib program, asserted GO-1713-GATE:21 + version go${VERSION}"
} > "${OUTPUT_DIR}/usr/share/go-${VERSION}/BUILDINFO"
