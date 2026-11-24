#!/bin/sh
set -e

tar -xof "Python-${MINIMAL_ARG_VERSION}.tar.xz"
cd "Python-${MINIMAL_ARG_VERSION}"

# CVE-2025-15367 (gh-143923), the same backport as packages/python; see build.ncl.
# -F0 refuses fuzzy hunks, so a context drift on a bump fails the build.
patch -Np1 -F0 -i "../0003-gh-143923-poplib-reject-control-characters.patch"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# Static interpreter under a private prefix: no libpython.so, and no path that
# packages/python also ships. No ensurepip (no pip, no vendored CA bundle) and no
# test modules. Modules whose library is not in the build closure (ssl, sqlite3,
# ctypes, ...) are left out by configure; glibc's build scripts need none of them.
./configure --prefix=/usr/lib/python-bootstrap \
            --without-ensurepip \
            --disable-test-modules

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# Ship the interpreter and its standard library only: the static libpython,
# headers, pkg-config files and man pages are for embedding, which nothing does.
P="$OUTPUT_DIR/usr/lib/python-bootstrap"
rm -f "$P"/lib/libpython*.a "$P"/bin/python3*-config
rm -rf "$P/include" "$P/lib/pkgconfig" "$P/share" "$P"/lib/python3.*/config-3.*

# Fail closed if the interpreter is not static: it must not need a libpython.so
# that this package does not ship.
if readelf -d "$P/bin/python3" | grep -q 'NEEDED.*libpython'; then
  echo "python-bootstrap: bin/python3 links a shared libpython" >&2
  exit 1
fi
