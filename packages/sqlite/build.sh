#!/bin/sh
set -e

# Both names must match the archive in build.ncl. The 3.53.3 bump updated the
# `cd` but not the `tar`, so this extracted 3.50.4 and then changed into a
# directory that did not exist.
tar -xof sqlite-autoconf-3540100.tar.gz
cd sqlite-autoconf-3540100

# CVE-2026-119586 (.recover smuggles dot-commands from sqlite_schema.sql into
# its output). Upstream check-in d684ccc9ec4e41d8, re-targeted at the
# amalgamated shell.c; see the patch header. Drop it at the first release
# after 3.54.1 that contains that check-in. --fuzz=0: a hunk that only
# applies loosely means the tarball changed and the patch needs rereading.
patch -p1 --fuzz=0 < ../CVE-2026-119586-recover-tail.patch

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA $MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

./configure  --prefix=/usr         \
            --disable-static       \
            --enable-fts4          \
            --enable-fts5          \
            --enable-rtree         \
            --enable-session

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
