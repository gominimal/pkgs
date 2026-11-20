#!/bin/sh
set -e

tar -xof dejagnu-1.6.3.tar.gz
cd dejagnu-1.6.3

# Tcl 9 fixes from upstream (unreleased; Fedora's tcl9.patch, provenance in its
# header): expect now runs on Tcl 9. The digests cover the files it touches, so
# a different dejagnu source fails before patching and a misapplied patch after.
PATCHED="ChangeLog baseboards/qemu.exp lib/utils.exp runtest runtest.exp"
check_tree() {
  got=$(sha256sum $PATCHED | sha256sum | cut -d' ' -f1)
  if [ "$got" != "$1" ]; then
    echo "dejagnu: $2 sources digest $got, want $1" >&2
    sha256sum $PATCHED >&2
    exit 1
  fi
}
check_tree baadd139c42c7f6eb8f89c5094ccdcebb31979c17d304e0a05f86b151a068277 unpatched
patch -Np1 --fuzz=0 -i ../fedora-tcl9.patch
check_tree 05934478be2cffc2372922a74aa9c4c20e5dff833fc4900a43ae6d561a8276a3 patched

mkdir -v build
cd       build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

../configure --prefix=/usr
# expect is a build dep so this runs DejaGnu's own testsuite on it: without
# expect, automake's check-DEJAGNU only warns that runtest is unusable and passes.
make check
make DESTDIR=$OUTPUT_DIR install
