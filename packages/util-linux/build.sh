#!/bin/sh
set -e

tar -xof "util-linux-${MINIMAL_ARG_VERSION}.tar.xz"
cd "util-linux-${MINIMAL_ARG_VERSION}"

# 2.42.3's own CVE fix broke the build on both arches.
#
#   fb8e26535 "libmount: pin source path with openat2() for restricted users
#              [CVE-2026-78410]" made hook_mount_post() pass RESOLVE_NO_SYMLINKS
#              to mnt_open_tree(), but did not add the include that defines it.
#
# util-linux keeps a fallback in include/fileutils.h:
#     #ifndef RESOLVE_NO_SYMLINKS
#     # define RESOLVE_NO_SYMLINKS  0x02
#     #endif
# so the constant only reaches translation units that include that header.
# hook_idmap.c does not — its sibling hook_mount.c, which uses the same
# constant, does — giving:
#     libmount/src/hook_idmap.c:335:33: error: 'RESOLVE_NO_SYMLINKS' undeclared
#
# Distro builds where linux/openat2.h sits in the default sysroot pick the
# constant up from the kernel UAPI header and never notice. Ours is hermetic and
# util-linux declares no linux_headers dep, so the fallback is the only source.
#
# Upstream fixed it ONE DAY after the tag: 7e2e01087 "libmount: add missing
# fileutils.h include to hook_idmap.c". Applied here with sed rather than a
# .patch file on purpose: `patch` reaches util-linux only via `base`, and this
# package deliberately builds against `base-bootstrap` to stay out of that
# cycle. sed needs no closure change.
#
# DROP THIS at util-linux 2.42.4 or later — the include is already on upstream
# master, so the guard below will fail loudly once the bump carries it.
sed -i '/#include "all-io.h"/a #include "fileutils.h"' libmount/src/hook_idmap.c
grep -q '#include "fileutils.h"' libmount/src/hook_idmap.c || {
  echo "ERROR: hook_idmap.c fileutils.h include did not apply — upstream shape changed." >&2
  echo "       If this version already carries 7e2e01087, DELETE this sed + guard." >&2
  exit 1
}
# Fail loudly if upstream has since added it themselves: two copies means the
# workaround is obsolete and must be removed, not silently duplicated.
[ "$(grep -c '#include "fileutils.h"' libmount/src/hook_idmap.c)" = "1" ] || {
  echo "ERROR: hook_idmap.c now has MULTIPLE fileutils.h includes — upstream" >&2
  echo "       carries the fix; delete this sed + guard from build.sh." >&2
  exit 1
}

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
