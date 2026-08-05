#!/bin/sh
set -e

cd "diffutils-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
# The gnulib test suite shells out to `cmp` (15 call sites) and `diff` (2) — the very binaries
# this package provides. With the prebuilt breaker in place they are already in the sandbox;
# building from source, they are not, and 17 .sh tests fail with "cmp: command not found"
# while every compiled C test passes. Put the freshly-built ones on PATH: src/ holds diff and
# cmp after `make`, so the suite tests THIS build rather than needing a previous diffutils.
PATH="$PWD/src:$PATH"; export PATH
command -v cmp >/dev/null || { echo "diffutils: no cmp on PATH after build — expected $PWD/src/cmp" >&2; exit 1; }
command -v diff >/dev/null || { echo "diffutils: no diff on PATH after build" >&2; exit 1; }
echo "diffutils: self-testing with $(command -v diff) / $(command -v cmp)"
make check
make DESTDIR=$OUTPUT_DIR install-strip
