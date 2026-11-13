#!/bin/bash
set -eux

SRC=$(pwd)

# cvc5's patch (see build.ncl). Fail-closed: a rejected hunk aborts the build.
patch -Np1 -i cvc5-trace.patch

# --- Reproducibility --------------------------------------------------------
# Three things in CoCoALib's build stamp the build host or the wall clock:
#  - MakeUnifiedHeader.sh writes `date` into include/CoCoA/library.H;
#  - configure writes `date` into include/CoCoA/PREPROCESSOR_DEFNS.H;
#  - BuildInfo.o embeds the configure-time `uname -s -r -m` (the kernel
#    release) and the full CXXFLAGS string (it contains $SRC through
#    -ffile-prefix-map).
# All three headers are installed and BuildInfo.o is in libcocoa.a, so pin
# them. The `grep -q`s make each edit fail closed if upstream changes shape.
grep -q '^TODAY=`date' include/CoCoA/MakeUnifiedHeader.sh
sed -i 's/^TODAY=`date.*/TODAY=reproducible/' include/CoCoA/MakeUnifiedHeader.sh
grep -q -- '-DCOCOA_PLATFORM="\\"$(PLATFORM)\\""' src/AlgebraicCore/Makefile
sed -i -e '/-DCOCOA_PLATFORM=/s/-DCOCOA_CXXFLAGS="\\"$(CXXFLAGS)\\""/-DCOCOA_CXXFLAGS="\\"see-build.sh\\""/' \
       -e '/-DCOCOA_PLATFORM=/s/-DCOCOA_PLATFORM="\\"$(PLATFORM)\\""/-DCOCOA_PLATFORM="\\"Linux\\""/' \
       src/AlgebraicCore/Makefile
grep -q -- '-DCOCOA_CXXFLAGS="\\"see-build.sh\\""  -DCOCOA_PLATFORM="\\"Linux\\""' src/AlgebraicCore/Makefile

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
REPRO="-ffile-prefix-map=$SRC=/builddir -gno-record-gcc-switches"

# configure finds GMP through the path to the library; the headers must sit
# in the sibling include/ (it checks gmp.h's version against the library).
GMP_LIB=$(ls /usr/lib/libgmp.so /usr/lib64/libgmp.so 2>/dev/null | head -1)
test -n "$GMP_LIB"

# --only-cocoalib: just the library, not the CoCoA-5 interpreter, so no
# Boost or readline (this is what cvc5's ExternalProject does too).
# configure appends -std=c++14 (if needed), -O2 and its own warnings to these
# flags. It adds -fPIC only when no flags are given at all, so pass it here:
# cvc5-ff links libcocoa.a into libcvc5.so.
./configure \
  --prefix=/usr \
  --with-libgmp="$GMP_LIB" \
  --with-cxx=g++ \
  --with-cxxflags="$MARCH -fPIC -pipe $REPRO" \
  --only-cocoalib
grep -q -- '-fPIC' configuration/autoconf.mk

# The configure-time date in the installed PREPROCESSOR_DEFNS.H (a comment).
grep -q '^// Created on date' include/CoCoA/PREPROCESSOR_DEFNS.H
sed -i '/^\/\/ Created on date/d' include/CoCoA/PREPROCESSOR_DEFNS.H

# ARFLAGS on the command line overrides autoconf.mk's `-rcS` in every
# sub-make: D = deterministic member headers (no mtime/uid/gid).
make -j"$(nproc)" library ARFLAGS=-rcSD
# The top Makefile then indexes with a plain `ar -s`; redo it deterministically.
ranlib -D lib/libcocoa.a

# CoCoALib's `make install` insists on the PDF manual, prompts, and installs
# into versioned directories via symlinks plus a copy of autoconf.mk (which
# carries the build date and host). Install the two things consumers use by
# hand instead: the archive and the headers, in the layout cvc5's
# FindCoCoA.cmake looks for (CoCoA/library.H, libcocoa).
install -Dm644 lib/libcocoa.a "$OUTPUT_DIR/usr/lib/libcocoa.a"
mkdir -p "$OUTPUT_DIR/usr/include/CoCoA"
install -m644 include/CoCoA/*.H "$OUTPUT_DIR/usr/include/CoCoA/"

test -f "$OUTPUT_DIR/usr/include/CoCoA/library.H"
grep -q "^// Unified header file for CoCoALib version $MINIMAL_ARG_VERSION\$" "$OUTPUT_DIR/usr/include/CoCoA/library.H"
grep -q 'handlersEnabled' "$OUTPUT_DIR/usr/include/CoCoA/TmpGPoly.H"
if grep -rq 'Created on\|produced automatically by MakeUnifiedHeader.sh on [0-9]' "$OUTPUT_DIR/usr/include/CoCoA/"; then
  echo "a build date survived in the installed headers" >&2
  exit 1
fi
