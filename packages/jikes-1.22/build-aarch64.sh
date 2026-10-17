#!/bin/sh
# jikes-1.22 on aarch64: the root of the JVM ladder (see build.ncl), built by the toolchain gcc
# against production glibc and installed at /usr/lib/jikes-1.22. x86_64 uses build.sh.
set -ex

# start from an empty output (no findutils in the sandbox)
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do
    if [ -e "$_e" ] || [ -L "$_e" ]; then rm -r "$_e"; fi
  done
fi
mkdir -p "$OUTPUT_DIR"
VERSION="${MINIMAL_ARG_VERSION:-1.22}"
SRC_TARBALL="jikes-${VERSION}.tar.bz2"
SRC_SHA=0cb02c763bc441349f6d38cacd52adf762302cce3a08e269f1f75f726e6e14e3
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/jikes-${VERSION}"

# P0: preconditions
for t in gcc g++ as ld make sed grep tar bzip2 sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "jikes infra: '$t' not on PATH" >&2; exit 1; }
done
[ "$(uname -m)" = aarch64 ] || { echo "jikes infra: build-aarch64.sh on $(uname -m)" >&2; exit 1; }
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || { echo "jikes infra: source sha mismatch" >&2; exit 1; }

# P1: build
tar --no-same-owner -xjf "${SRC_TARBALL}"
[ -x "jikes-${VERSION}/configure" ] || { echo "jikes infra: expected jikes-${VERSION}/configure after untar" >&2; exit 1; }
cd "jikes-${VERSION}"
# config.sub/config.guess predate aarch64: take automake's, and name the platform
for f in config.sub config.guess; do cp "$(ls /usr/share/automake-*/$f | head -1)" "$f"; done
CC=gcc CXX=g++ CFLAGS="-O2" CXXFLAGS="-O2" \
  ./configure --prefix="${PREFIX}" --disable-dependency-tracking \
    --build=aarch64-unknown-linux-gnu --host=aarch64-unknown-linux-gnu \
  || { sed -n '/C++ compiler default output/,/^## -/p' config.log | grep -v '^| ' | head -40 >&2; tail -30 config.log >&2; exit 1; }
make -j"$(nproc 2>/dev/null || echo 4)"
make install DESTDIR="${OUTPUT_DIR}"
cd "${BUILDROOT}"

# P2: gate. The binary runs and reports its version.
J="${OUTPUT_DIR}${PREFIX}/bin/jikes"
[ -x "${J}" ] || { echo "jikes: bin/jikes missing after install" >&2; exit 1; }
"${J}" --version 2>&1 | grep -q 'Jikes Compiler' || { echo "jikes: --version did not identify the compiler" >&2; "${J}" --version >&2 || true; exit 1; }
mkdir -p "${OUTPUT_DIR}/usr/share/jikes-${VERSION}"
{
  echo "package:     jikes-${VERSION} (JVM ladder rung 1, the C++ Java compiler)"
  echo "source:      ${SRC_TARBALL} sha256 ${SRC_SHA}"
  echo "compiler:    $(command -v g++) ($(g++ -dumpversion), toolchain)"
  echo "prefix:      ${PREFIX}"
  echo "version:     $("${J}" --version 2>&1 | head -1)"
} > "${OUTPUT_DIR}/usr/share/jikes-${VERSION}/BUILDINFO"
echo "jikes-${VERSION}: built and gated" >&2
