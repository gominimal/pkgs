#!/bin/sh
# go-1.4: root of the Go bootstrap ladder.  Builds Go 1.4, the last release whose whole toolchain
# (including src/cmd/dist) is C, from go1.4-bootstrap-20171003.tar.gz with gcc-15.2.0-glibc and
# installs the whole GOROOT to /usr/lib/go-1.4 as the GOROOT_BOOTSTRAP of go-1.17.13.
# gcc-15 defaults to C23, where `bool` is a keyword and cmd/dist/a.h's `typedef int bool;` is a
# hard error under make.bash's -Werror, so CC carries -std=gnu17 -Wno-error.
# phases: P0 preconditions, P1 sysroot CC wrapper, P2 make.bash, P3 install, gate.
set -ex

# Start from an empty $OUTPUT_DIR: a persistent build root could leave a stale partial install
# that the output globs would capture.  Pure coreutils: no findutils in the sandbox.
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
VERSION="${MINIMAL_ARG_VERSION:-1.4}"
SRC_TARBALL="go1.4-bootstrap-20171003.tar.gz"
SRC_SHA=f4ff5b5eb3a3cae1c993723f3eab519c5bae18866b5e5f96fe1102f0cb5c3e52
BUILDROOT="$(pwd)"
PREFIX_REL=usr/lib/go-1.4          # runtime prefix, baked in via GOROOT_FINAL
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42     # versioned glibc sysroot: headers, crt, libs
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

# --- P0 preconditions: the expected gcc, the glibc sysroot and the pinned source must be present ---
BGCC="$(command -v gcc || true)"
[ -n "${BGCC}" ] || { echo "go-1.4: gcc not on PATH" >&2; exit 1; }
for t in as ld ar ranlib objcopy strip make sed grep tar bash uname sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "go-1.4 infra: '$t' not on PATH" >&2; exit 1; }
done
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || {
  echo "go-1.4: gcc -dumpversion = '${GCCVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc)." >&2
  echo "              Refusing to build: an unexpected host compiler makes this edge meaningless." >&2
  exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "go-1.4: glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]  || { echo "go-1.4: glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]         || { echo "go-1.4: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SRC_TARBALL}" ]    || { echo "go-1.4 infra: source ${SRC_TARBALL} absent" >&2; exit 1; }

# fail shut on any drift from the pinned sha
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || {
  echo "go-1.4 infra: source sha mismatch — refusing to build an unpinned bootstrap" >&2; exit 1; }

# --- P1 CC wrapper against the versioned sysroot ---
# The sysroot's libc.so is a linker script whose paths point at its own staging directory,
# which does not exist here; regenerate a corrected script that ld finds first.
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

# The CC make.bash uses.  -std=gnu17 -Wno-error: see the header.  -nostdinc plus explicit
# -isystem keeps any ambient /usr/include out of the bootstrap.
cat > "${BUILDROOT}/go-cc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BGCC}" -nostdinc -std=gnu17 -Wno-error ${INC} "\$@" ;; esac; done
exec "${BGCC}" -nostdinc -std=gnu17 -Wno-error ${INC} ${LNK} "\$@"
WRAP
chmod +x "${BUILDROOT}/go-cc"

# --- P2 build: make.bash builds cmd/dist (C), which builds the rest ---
# CGO_ENABLED=0 keeps the host libc and headers out; GOROOT_FINAL bakes the runtime prefix.
tar --no-same-owner -xzf "${SRC_TARBALL}"
# sha-pinned archive: it unpacks to ./go.  No `find`: findutils is not in the sandbox.
GODIR=go
DISTDIR="${GODIR}/src/cmd/dist"
[ -d "${DISTDIR}" ] || {
  echo "go-1.4 infra: expected ${DISTDIR} after untar (sha-pinned archive, layout is fixed). cwd:" >&2
  ls -la >&2
  exit 1; }
echo "go-1.4: source tree = ${GODIR}" >&2
# Assert the C-hosted premise on the source being built.  Shell globs, not find: a
# non-matching glob stays literal, so test -f.
NC=0; for f in "${DISTDIR}"/*.c;  do [ -f "$f" ] && NC=$((NC+1)); done
NG=0; for f in "${DISTDIR}"/*.go; do [ -f "$f" ] && NG=$((NG+1)); done
[ "${NC}" -gt 0 ] && [ "${NG}" -eq 0 ] || {
  echo "go-1.4 infra: src/cmd/dist is not C-hosted (.c=${NC} .go=${NG}) — this is not the bootstrap Go" >&2
  exit 1; }
echo "go-1.4: C-hosted bootstrap confirmed (src/cmd/dist .c=${NC} .go=${NG})" >&2

# TMPDIR: go1.4's dist (src/cmd/dist/unix.c xtmpdir) falls back to /var/tmp, absent in the sandbox.
GOTMP="${BUILDROOT}/gotmp"; mkdir -p "${GOTMP}"
cd "${GODIR}/src"
CC="${BUILDROOT}/go-cc" \
CGO_ENABLED=0 \
TMPDIR="${GOTMP}" \
GOROOT_FINAL="/${PREFIX_REL}" \
GOOS=linux GOARCH=amd64 GOHOSTOS=linux GOHOSTARCH=amd64 \
  ./make.bash
cd "${BUILDROOT}"

# --- P3 install the whole GOROOT (bin + pkg + src + lib) ---
# A Go toolchain compiles the stdlib sources of its own GOROOT, and the next rung uses this
# tree as GOROOT_BOOTSTRAP.
DEST="${OUTPUT_DIR}/${PREFIX_REL}"
mkdir -p "${DEST}"
cp -a "${GODIR}/." "${DEST}/"
# drop build-only trees
rm -rf "${DEST}/.git" "${DEST}/test" 2>/dev/null || true
[ -x "${DEST}/bin/go" ] || { echo "go-1.4: FATAL bin/go missing after install" >&2; exit 1; }

# --- gate: compile and run a program and assert its output ---
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

# provenance record
mkdir -p "${OUTPUT_DIR}/usr/share/go-1.4"
{
  echo "go-1.4"
  echo "source:      ${SRC_TARBALL}  sha256=${SRC_SHA}"
  echo "built_by:    gcc ${GCCVER} (gcc-15.2.0-glibc)"
  echo "sysroot:     ${SR} (glibc-bedrock-2.42)"
  echo "c23_fix:     CC carries -std=gnu17 (gcc-15 makes 'bool' a keyword; cmd/dist/a.h typedefs it)"
  echo "cgo:         disabled"
  echo "goroot_final:/${PREFIX_REL}"
  echo "gate:        compiled+ran a Go program, asserted output GO14-GATE:21"
} > "${OUTPUT_DIR}/usr/share/go-1.4/BUILDINFO"
