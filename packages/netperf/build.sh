#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# Two build fixes are open upstream but unmerged, so they are compiler flags here
# rather than carried patches:
#  - -std=gnu17: netlib.h declares functions with empty parameter lists
#    (`allocate_buffer_ring()`), which C23, GCC 15's default, reads as "no arguments",
#    so every call fails "too many arguments". HewlettPackard/netperf#86 writes out the
#    prototypes.
#  - -D_GNU_SOURCE: sched_setaffinity (netlib.c, CPU binding with -T) and splice
#    (nettest_omni.c) are GNU extensions; without it they are implicit declarations,
#    an error since GCC 14. HewlettPackard/netperf#74 adds AC_USE_SYSTEM_EXTENSIONS,
#    which defines the same macro through config.h.
export CFLAGS="$CFLAGS -std=gnu17"
export CPPFLAGS="-D_GNU_SOURCE"

# A commit archive has no generated configure; this is upstream's autogen.sh.
aclocal -I src/missing/m4
automake --add-missing
autoconf
autoheader

# doc/netperf.info is committed next to netperf.texi. Extraction does not keep the
# archive's mtimes, so make the info file newer: otherwise make tries to regenerate it
# with makeinfo, which this build does not have (and the info manual is not shipped).
touch doc/netperf.info

# --enable-demo: interim results with -D (netperf -D 1 prints the rate every second),
# which a lab scenario uses to watch a run. Burst (-b in the _RR tests) and the omni
# tests (TCP_RR, UDP_RR, ...) are on by default.
./configure --prefix=/usr --mandir=/usr/share/man --enable-demo

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# Only the two programs and their man pages are shipped; the info manual is not.
rm -rf "$OUTPUT_DIR/usr/share/info"
sha256sum "$OUTPUT_DIR"/usr/bin/netperf "$OUTPUT_DIR"/usr/bin/netserver
