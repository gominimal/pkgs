#!/bin/sh
set -e

tar -xof "util-linux-${MINIMAL_ARG_VERSION}.tar.xz"
cd "util-linux-${MINIMAL_ARG_VERSION}"

# 2.42.3 needed a sed here: its own CVE fix (fb8e26535, CVE-2026-78410) passed
# RESOLVE_NO_SYMLINKS out of hook_mount_post() without including the header that
# defines it, and this build is hermetic with no linux_headers dep, so
# include/fileutils.h's fallback was the only source of the constant.
#
# Upstream fixed it one day after the tag (7e2e01087) and 2.42.4 CARRIES it:
# hook_idmap.c now includes fileutils.h immediately after all-io.h — the exact
# line the sed used to insert. The workaround's own tripwire caught the bump
# ("hook_idmap.c now has MULTIPLE fileutils.h includes"), which is the guard
# doing precisely what it was written to do, and its comment said to drop the
# block at 2.42.4 or later. Dropped.

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            --without-systemd     \
            --without-systemdsystemunitdir        \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux    \
            --disable-makeinstall-chown \
            --disable-makeinstall-setuid \
            --disable-use-tty-group     \

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
