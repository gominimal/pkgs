#!/bin/sh
# ============================================================================================
# build.sh — go-1.4: THE GO JOINT (issue #19).  The last C-hosted Go toolchain, built by our
# seed-rooted gcc-15.2.0 (B5) — the rung that replaces the trust-by-fiat go.dev bindist.
#
#   IS:     /usr/lib/go-1.4/{bin/go,bin/gofmt,pkg,src,lib} — a WORKING Go 1.4 toolchain whose
#           only compiler input was C, compiled by the B5 g++/gcc whose own chain is
#           hex0 -> hex1 -> ... -> tcc -> gcc-4.0.4 -> ... -> gcc-15.2.0 -> gcc-15.2.0-glibc.
#   IS NOT: a modern Go.  Go 1.4 is the BOOTSTRAP: it builds go-1.17.13, which builds 1.20.14,
#           1.22.6, 1.24.x and finally the shipped `go`.  Each of those is its own rung that
#           imports its predecessor and sets GOROOT_BOOTSTRAP — exactly the mrustc->rustc shape.
#
# WHY GO 1.4 SPECIFICALLY: it is the LAST Go release whose whole toolchain is written in C
# (src/cmd/dist is 10 .c files and ZERO .go files — verified).  Go 1.5+ is self-hosted, so a
# pre-existing Go binary is required — the chicken-and-egg this rung breaks with gcc alone.
#
# ── THE ONE WALL (de-risked 2026-07-26) ──────────────────────────────────────────────────────
# gcc-15 defaults to C23, where `bool` is a KEYWORD.  go1.4's cmd/dist/a.h:5 says
# `typedef int bool;` -> "error: 'bool' cannot be defined via 'typedef'" + "useless type name in
# empty declaration [-Werror]" (make.bash hardcodes -Werror).  Pinning -std=gnu17 makes `bool`
# an ordinary identifier again and the whole build goes green (rc=0, zero errors).  This is the
# SAME C23 trap family as the aarch64 ladder's musl basename() and libiberty K&R malloc() walls.
# ============================================================================================
set -ex
VERSION="${MINIMAL_ARG_VERSION:-1.4}"
SRC_TARBALL="go1.4-bootstrap-20171003.tar.gz"
SRC_SHA=f4ff5b5eb3a3cae1c993723f3eab519c5bae18866b5e5f96fe1102f0cb5c3e52
BUILDROOT="$(pwd)"
PREFIX_REL=usr/lib/go-1.4          # where the toolchain lives at RUNTIME (baked via GOROOT_FINAL)
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42     # B4 versioned sysroot: headers + crt + libs + co-located UAPI
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

# ============================================================================================
# P0 — PRECONDITIONS.  Assert the ANCHOR, not just "a compiler".  A wrong or ambient gcc here
# would produce a green build that proves NOTHING about seed-rooting.
# ============================================================================================
BGCC="$(command -v gcc || true)"
[ -n "${BGCC}" ] || { echo "go-1.4 infra: B5 gcc not on PATH" >&2; exit 1; }
for t in as ld ar ranlib objcopy strip make sed grep tar bash uname sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "go-1.4 infra: '$t' not on PATH" >&2; exit 1; }
done
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || {
  echo "go-1.4 infra: gcc -dumpversion = '${GCCVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc, B5)." >&2
  echo "              Refusing to build: an unexpected host compiler makes this edge meaningless." >&2
  exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "go-1.4 infra: B4 sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]  || { echo "go-1.4 infra: B4 startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]         || { echo "go-1.4 infra: B4 loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SRC_TARBALL}" ]    || { echo "go-1.4 infra: source ${SRC_TARBALL} absent" >&2; exit 1; }

# SOURCE PIN — fail shut on any drift from the sha we mirrored + de-risked against.
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || {
  echo "go-1.4 infra: source sha mismatch — refusing to build an unpinned bootstrap" >&2; exit 1; }

# ============================================================================================
# P1 — SYSROOT HARNESS (B5's proven flag set + the B4 libc.so linker-script fixup).
# The sealed B4 versioned libc.so is a linker SCRIPT that baked /build/output/... staging paths
# which do not exist at build time; regenerate a corrected script that ld finds FIRST.
# ============================================================================================
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then
  echo "go-1.4 infra: libc.so linker-script fixup failed (staging paths survive)" >&2; exit 1
fi

GI="$("${BGCC}" -print-file-name=include)"
[ -d "${GI}" ] || { echo "go-1.4 infra: gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }
INC="-isystem ${GI} -isystem ${SR}/include"
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"

# The CC go1.4's make.bash will use.  -std=gnu17 is THE de-risked fix (see the banner);
# -Wno-error because make.bash hardcodes -Werror and 2014-era C trips modern warnings.
# -nostdinc + explicit -isystem keeps any ambient /usr/include out of the bootstrap.
cat > "${BUILDROOT}/go-cc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BGCC}" -nostdinc -std=gnu17 -Wno-error ${INC} "\$@" ;; esac; done
exec "${BGCC}" -nostdinc -std=gnu17 -Wno-error ${INC} ${LNK} "\$@"
WRAP
chmod +x "${BUILDROOT}/go-cc"

# ============================================================================================
# P2 — BUILD.  make.bash runs from src/ and builds cmd/dist (C) which then builds the rest.
# CGO_ENABLED=0: no cgo in the bootstrap (it would drag the host's libc/headers back in, and
# nothing in the ladder needs cgo from the 1.4 rung).  GOROOT_FINAL bakes the RUNTIME prefix.
# ============================================================================================
tar --no-same-owner -xzf "${SRC_TARBALL}"
GODIR="$(ls -d go 2>/dev/null || ls -d go* 2>/dev/null | head -1)"
[ -d "${GODIR}/src" ] || { echo "go-1.4 infra: unpacked tree has no src/ (got '${GODIR}')" >&2; exit 1; }
# Confirm the C-hosted premise on the ACTUAL bytes we are building (not on a memory of it).
NC="$(find "${GODIR}/src/cmd/dist" -name '*.c' | wc -l)"
NG="$(find "${GODIR}/src/cmd/dist" -name '*.go' | wc -l)"
[ "${NC}" -gt 0 ] && [ "${NG}" -eq 0 ] || {
  echo "go-1.4 infra: src/cmd/dist is not C-hosted (.c=${NC} .go=${NG}) — this is not the bootstrap Go" >&2
  exit 1; }
echo "go-1.4: C-hosted bootstrap confirmed (src/cmd/dist .c=${NC} .go=${NG})" >&2

cd "${GODIR}/src"
CC="${BUILDROOT}/go-cc" \
CGO_ENABLED=0 \
GOROOT_FINAL="/${PREFIX_REL}" \
GOOS=linux GOARCH=amd64 GOHOSTOS=linux GOHOSTARCH=amd64 \
  ./make.bash
cd "${BUILDROOT}"

# ============================================================================================
# P3 — INSTALL.  make.bash builds in-tree; ship the whole GOROOT (bin + pkg + src + lib).
# src/ MUST ship: a Go toolchain compiles the stdlib sources of its own GOROOT, and the next
# rung's make.bash needs this tree complete to act as GOROOT_BOOTSTRAP.
# ============================================================================================
DEST="${OUTPUT_DIR}/${PREFIX_REL}"
mkdir -p "${DEST}"
cp -a "${GODIR}/." "${DEST}/"
# Drop the build-only droppings (keep the tree lean + deterministic).
rm -rf "${DEST}/.git" "${DEST}/test" 2>/dev/null || true
[ -x "${DEST}/bin/go" ] || { echo "go-1.4: FATAL bin/go missing after install" >&2; exit 1; }

# ============================================================================================
# FUNCTIONAL GATE — FAIL-SHUT.  This project's scar tissue: a `--version`-only gate once shipped
# an `as` that could not assemble, for days.  So this gate makes the freshly-built C-rooted Go
# actually COMPILE AND RUN a program, and asserts on the OUTPUT VALUE.
# ============================================================================================
GATE="${BUILDROOT}/go14gate"; mkdir -p "${GATE}"
cat > "${GATE}/hello.go" <<'EOF'
package main

import "fmt"

func main() {
	sum := 0
	for i := 1; i <= 6; i++ {
		sum += i
	}
	fmt.Printf("GO14-GATE:%d\n", sum)
}
EOF
set +e
GOUT="$(cd "${GATE}" && GOROOT="${DEST}" GOPATH="${GATE}/gopath" CGO_ENABLED=0 \
  timeout 120 "${DEST}/bin/go" run hello.go 2>"${GATE}/err")"
grc=$?
set -e
if [ "${GOUT}" = "GO14-GATE:21" ]; then
  echo "GO14-GATE: PASS (C-rooted Go 1.4 compiled AND RAN a program; got '${GOUT}')" >&2
else
  echo "GO14-GATE: FAIL (rc=${grc}, got '${GOUT}', want 'GO14-GATE:21'); tail:" >&2
  tail -20 "${GATE}/err" >&2 || true
  exit 1
fi

# Provenance record — what built this, from what, with which fix.
mkdir -p "${OUTPUT_DIR}/usr/share/go-1.4"
{
  echo "go-1.4 (the Go bootstrap joint, issue #19)"
  echo "source:      ${SRC_TARBALL}  sha256=${SRC_SHA}"
  echo "built_by:    gcc ${GCCVER} (gcc-15.2.0-glibc, B5 — seed-rooted to the 229-byte hex0 seed)"
  echo "sysroot:     ${SR} (glibc-bedrock-2.42, B4)"
  echo "c23_fix:     CC carries -std=gnu17 (gcc-15 makes 'bool' a keyword; cmd/dist/a.h typedefs it)"
  echo "cgo:         disabled"
  echo "goroot_final:/${PREFIX_REL}"
  echo "gate:        compiled+ran a Go program, asserted output GO14-GATE:21"
} > "${OUTPUT_DIR}/usr/share/go-1.4/BUILDINFO"
