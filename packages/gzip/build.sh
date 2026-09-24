#!/bin/sh
set -e

tar -xof gzip-1.15.tar.xz
cd gzip-1.15

# gzip 1.15 moved `#include "gzip.h"` above <signal.h>. gzip.h does
# `#define head (prev+WSIZE)`, and on aarch64 <signal.h> pulls in the kernel's
# asm/sigcontext.h, whose signal-frame structs all have a member named `head`.
# The macro rewrites them and gzip.c fails to compile on arm64 ("expected ')'
# before '+' token"). 1.14 included <signal.h> first, which is why it built.
# Upstream fix, not in any release yet: gzip commit b4ed8e73 ("build: avoid
# failure to build on linux aarch64", https://bugs.gnu.org/81904), which moves
# the include below every system header. Applied here with sed, not `patch`:
# patch depends on base, which contains gzip, so a patch dependency would be a
# cycle. Guarded to run only while the broken order is present, so a release
# that carries the fix skips it. Drop this block when bumping past 1.15.
gzip_h=$(grep -n '^#include "gzip.h"$' gzip.c | cut -d: -f1)
signal_h=$(grep -n '^#include <signal.h>$' gzip.c | cut -d: -f1)
if [ -n "$gzip_h" ] && [ -n "$signal_h" ] && [ "$gzip_h" -lt "$signal_h" ]; then
  sed -i '/^#include "gzip.h"$/d' gzip.c
  sed -i 's|^#ifndef MAX_PATH_LEN$|#include "gzip.h"\n\n&|' gzip.c
  gzip_h=$(grep -n '^#include "gzip.h"$' gzip.c | cut -d: -f1)
  signal_h=$(grep -n '^#include <signal.h>$' gzip.c | cut -d: -f1)
  if [ "$(grep -c '^#include "gzip.h"$' gzip.c)" != 1 ] || [ "$gzip_h" -le "$signal_h" ]; then
    echo "gzip.h include move (upstream b4ed8e73) did not apply" >&2
    exit 1
  fi
fi

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
make check
make DESTDIR=$OUTPUT_DIR install
