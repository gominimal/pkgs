#!/bin/sh
set -e

tar -xof bison-3.8.2.tar.xz
cd bison-3.8.2

# Security backports from bison master; see build.ncl. Each patch is applied
# before configure, so a failed hunk fails the build under `set -e`. -F0
# refuses fuzzy hunks, so context drift fails the build rather than patching
# the wrong place. The patches live one level up because the tarball extracts
# into a subdirectory.
patch -Np1 -F0 -i ../0001-CVE-2026-56389-html-xsltproc-from-PATH.patch
patch -Np1 -F0 -i ../0002-CVE-2026-56390-output-file-names.patch
# 0002 edits src/parse-gram.y along with the generated parse-gram.[ch] it
# carries. Make sure the generated files are not older than the grammar, so
# make never tries to regenerate them with the not-yet-built bison.
touch src/parse-gram.c src/parse-gram.h

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2

make -j$(nproc)
# make check # TODO
make DESTDIR=$OUTPUT_DIR install
