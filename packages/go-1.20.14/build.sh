#!/bin/sh
# go-1.20.14: one rung of the Go bootstrap ladder.  Builds Go 1.20.14 from go1.20.14.src.tar.gz with the
# previous rung (/usr/lib/go-1.17.13) as GOROOT_BOOTSTRAP and installs the whole GOROOT to
# /usr/lib/go-1.20.14 for the next rung to consume.
# phases: P0 preconditions, P1 writable bootstrap copy, P2 make.bash, P3 install, gate.
# Per-rung values: VERSION, SRC_SHA, BOOTSTRAP_PREFIX and the bootstrap version asserted in P1.
set -ex

# Start from an empty $OUTPUT_DIR: a persistent build root could leave a stale partial install
# that the output globs would capture.  Pure coreutils: no findutils in the sandbox.
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
VERSION="${MINIMAL_ARG_VERSION:-1.20.14}"
SRC_TARBALL="go${VERSION}.src.tar.gz"
SRC_SHA=1aef321a0e3e38b7e91d2d7eb64040666cabdcc77d383de3c9522d0d69b67f4e
BUILDROOT="$(pwd)"
PREFIX_REL="usr/lib/go-${VERSION}"
BOOTSTRAP_PREFIX=/usr/lib/go-1.17.13   # the previous rung (a build_dep)
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

# --- P0 preconditions: the expected gcc, the previous rung and the pinned source must be present ---
BGCC="$(command -v gcc || true)"
[ -n "${BGCC}" ] || { echo "go-1.20.14: gcc not on PATH" >&2; exit 1; }
for t in as ld ar ranlib make sed grep tar bash uname sha256sum cp mkdir; do
  command -v "$t" >/dev/null 2>&1 || { echo "go-1.20.14 infra: '$t' not on PATH" >&2; exit 1; }
done
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || {
  echo "go-1.20.14: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc)" >&2; exit 1; }
[ -x "${BOOTSTRAP_PREFIX}/bin/go" ] || {
  echo "go-1.20.14 infra: predecessor go-1.17.13 is missing at ${BOOTSTRAP_PREFIX}/bin/go — that rung IS the anchor" >&2
  exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "go-1.20.14: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -f "${SRC_TARBALL}" ]    || { echo "go-1.20.14 infra: source ${SRC_TARBALL} absent" >&2; exit 1; }
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || {
  echo "go-1.20.14 infra: source sha mismatch — refusing to build unpinned" >&2; exit 1; }

# --- P1 writable GOROOT_BOOTSTRAP ---
# The hydrated build_dep prefix is read-only, and a bootstrap `go build` may write into its own
# GOROOT/pkg, so bootstrap from a copy.
BOOT="${BUILDROOT}/boot-go"
cp -a "${BOOTSTRAP_PREFIX}" "${BOOT}"
[ -x "${BOOT}/bin/go" ] || { echo "go-1.20.14 infra: writable go-1.17.13 copy has no bin/go" >&2; exit 1; }
# The bootstrap Go needs GOROOT set: its baked GOROOT_FINAL is not this copy.
BOOTVER="$(GOROOT="${BOOT}" "${BOOT}/bin/go" version 2>&1 || true)"
echo "go-1.20.14: bootstrap Go = ${BOOTVER}" >&2
case "${BOOTVER}" in *go1.17.13*) : ;; *)
  echo "go-1.20.14 infra: bootstrap go version is '${BOOTVER}', expected go1.17.13 (the predecessor rung)" >&2
  exit 1 ;; esac

# --- P2 build: make.bash compiles cmd/dist with $GOROOT_BOOTSTRAP, then dist builds the toolchain ---
# CGO_ENABLED=0 keeps the host libc and headers out of the bootstrap.
tar --no-same-owner -xzf "${SRC_TARBALL}"
# sha-pinned archive: the official go source tarball unpacks to ./go
GODIR=go
[ -d "${GODIR}/src" ] || { echo "go-1.20.14 infra: expected ./go/src after untar. cwd:" >&2; ls -la >&2; exit 1; }
# This rung is self-hosted: src/cmd/dist is Go source, so a working bootstrap Go is required.
NG=0; for f in "${GODIR}"/src/cmd/dist/*.go; do [ -f "$f" ] && NG=$((NG+1)); done
[ "${NG}" -gt 0 ] || { echo "go-1.20.14 infra: src/cmd/dist has no .go files (${NG}) — unexpected source" >&2; exit 1; }
echo "go-1.20.14: self-hosted dist confirmed (${NG} .go files) — requires the C-rooted go-1.4" >&2

GOTMP="${BUILDROOT}/gotmp"; mkdir -p "${GOTMP}"     # Go's dist falls back to /var/tmp, absent in the sandbox
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

# --- P3 install the whole GOROOT (bin + pkg + src + lib) ---
# A Go toolchain compiles the stdlib sources of its own GOROOT, and the next rung uses this
# tree as GOROOT_BOOTSTRAP.
DEST="${OUTPUT_DIR}/${PREFIX_REL}"
mkdir -p "${DEST}"
cp -a "${GODIR}/." "${DEST}/"
rm -rf "${DEST}/.git" "${DEST}/test" "${DEST}/api" 2>/dev/null || true
[ -x "${DEST}/bin/go" ] || { echo "go-1.20.14: FATAL bin/go missing after install" >&2; exit 1; }

# --- gate: compile and run a program, assert its output and the reported toolchain version ---
# A wrong-version toolchain would break the next rung's minimum-bootstrap check.
GATE="${BUILDROOT}/gogate"; mkdir -p "${GATE}"
cat > "${GATE}/hello.go" <<'EOF'
package main

import (
	"fmt"
	"strings"
)

func main() {
	// exercise the stdlib, not just the parser
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
  echo "GO12014-GATE: FAIL (rc=${grc}, got '${GOUT}', want 'GO-12014-GATE:21'); tail:" >&2
  tail -20 "${GATE}/err" >&2 || true
  exit 1
fi

mkdir -p "${OUTPUT_DIR}/usr/share/go-${VERSION}"
{
  echo "go-${VERSION}"
  echo "source:       ${SRC_TARBALL}  sha256=${SRC_SHA}"
  echo "bootstrapped: ${BOOTVER}  (from ${BOOTSTRAP_PREFIX} — the C-rooted go-1.4 joint)"
  echo "built_by:     that Go; C toolchain gcc ${GCCVER} (gcc-15.2.0-glibc) available for cgo-less probes"
  echo "cgo:          disabled"
  echo "goroot_final: /${PREFIX_REL}"
  echo "gate:         compiled+ran a stdlib program, asserted GO-12014-GATE:21 + version go${VERSION}"
} > "${OUTPUT_DIR}/usr/share/go-${VERSION}/BUILDINFO"
