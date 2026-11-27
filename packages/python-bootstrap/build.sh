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
# test modules.
#
# The runtime closure is [glibc], but the build closure holds more: base brings
# bzip2, xz, ncurses and readline, toolchain brings zlib and zstd. Configure
# would find them and build modules that NEED a library no box has. So every
# module that links a library outside glibc is switched off (py_cv_module_X=n/a)
# and binascii is kept off zlib (it uses zlib's crc32 when configure finds it).
# glibc's build scripts need none of them; the NEEDED check below fails the
# build if configure finds a library anyway.
py_cv_module_zlib=n/a \
py_cv_module__bz2=n/a \
py_cv_module__lzma=n/a \
py_cv_module__zstd=n/a \
py_cv_module__curses=n/a \
py_cv_module__curses_panel=n/a \
py_cv_module_readline=n/a \
py_cv_module__dbm=n/a \
py_cv_module__gdbm=n/a \
py_cv_module__sqlite3=n/a \
py_cv_module__ssl=n/a \
py_cv_module__hashlib=n/a \
py_cv_module__uuid=n/a \
py_cv_module__ctypes=n/a \
py_cv_module__tkinter=n/a \
PKG_CONFIG=false \
ac_cv_header_zlib_h=no \
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

# Fail closed on a NEEDED library that glibc does not provide: the runtime
# closure is [glibc], and stdlib is OutputData, so minimal's missing-runtime_deps
# check does not read the extension modules.
find "$P/bin" "$P/lib" -type f \( -path "$P/bin/*" -o -name '*.so' \) > elfs.txt
bad=0
while IFS= read -r f; do
  readelf -h "$f" >/dev/null 2>&1 || continue
  for lib in $(readelf -d "$f" | sed -n 's/.*(NEEDED).*\[\(.*\)\]$/\1/p'); do
    case $lib in
      libc.so.6 | libm.so.6 | libpthread.so.0 | libdl.so.2 | librt.so.1 | libutil.so.1 | ld-linux-*.so.*) ;;
      *)
        echo "python-bootstrap: ${f#"$P"/} NEEDs $lib, which glibc does not provide" >&2
        bad=1
        ;;
    esac
  done
done < elfs.txt
[ "$bad" -eq 0 ] || exit 1
