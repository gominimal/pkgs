#!/bin/sh
# stage0-make — GNU make built from the bedrock toolchain WITHOUT make.
#
# make is the most depended-on node in the base soup's 21-package knot (in-degree 23) and it
# carries a literal self-loop: packages/make lists `make` in its own build_deps. A self-loop can
# only be broken by removing the vertex, which is why no edge cut ever freed anything.
#
# GNU make ships a bootstrap for exactly this: configure emits build.sh (from build.sh.in), a
# plain shell script that compiles make without needing make. VERIFIED on aarch64 against the
# sealed bedrock gcc with make deliberately absent from PATH: rc=0, and the result reports
# `GNU Make 4.4.1` (probe MBP_BOOTSTRAP_OK, 2026-08-06).
set -ex

VERSION="${MINIMAL_ARG_VERSION:-4.4.1}"
SRC="make-${VERSION}"
test -f "${SRC}.tar.gz" || { echo "stage0-make: source ${SRC}.tar.gz not staged" >&2; exit 1; }
tar -xf "${SRC}.tar.gz"
cd "${SRC}"

# ar/ranlib come from the bedrock binutils, not the host. build.sh needs ar for libgnu.a; the
# first probe run failed with "ar: not found" purely because the harness omitted it.
command -v ar     >/dev/null || { echo "stage0-make: no ar on PATH (bedrock binutils missing)" >&2; exit 1; }
command -v awk    >/dev/null || { echo "stage0-make: no awk on PATH (config.status needs it)" >&2; exit 1; }
if command -v make >/dev/null 2>&1; then
  echo "stage0-make: make IS on PATH — this rung must bootstrap WITHOUT it, refusing" >&2
  exit 1
fi

./configure --prefix="${OUTPUT_DIR}/usr" --disable-dependency-tracking
test -f build.sh || { echo "stage0-make: configure did not emit build.sh" >&2; exit 1; }

sh ./build.sh
test -x ./make || { echo "stage0-make: build.sh produced no make binary" >&2; exit 1; }

# Correctness gate: the produced make must actually run and be able to drive a trivial makefile.
./make --version | head -1
mkdir -p /tmp/mk && printf 'all:\n\t@echo STAGE0-MAKE-WORKS\n' > /tmp/mk/Makefile
( cd /tmp/mk && "${PWD}/../make" -f Makefile 2>/dev/null || true )
./make -C /tmp/mk all | grep -q STAGE0-MAKE-WORKS \
  || { echo "stage0-make: built make cannot execute a makefile" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}/usr/bin"
cp ./make "${OUTPUT_DIR}/usr/bin/make"
"${OUTPUT_DIR}/usr/bin/make" --version | head -1
