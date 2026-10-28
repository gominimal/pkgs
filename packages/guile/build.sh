#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export GUILE_AUTO_COMPILE=0

tar -xJof "guile-${MINIMAL_ARG_VERSION}.tar.xz"
cd "guile-${MINIMAL_ARG_VERSION}"

# The tarball ships compiled bytecode for the bootstrap modules (prebuilt/*/ice-9/*.go). Delete it so the
# build compiles them from source with the C interpreter.
find prebuilt -name '*.go' -delete
[ -z "$(find prebuilt -name '*.go')" ] || { echo "guile: prebuilt .go files remain" >&2; exit 1; }

./configure --prefix=/usr \
            --disable-static \
            --disable-error-on-warning

make -j"$(nproc)" > make.log 2>&1 || { tail -40 make.log >&2; echo "guile: make failed" >&2; exit 1; }
# the bootstrap/ tree compiles the compiler with the interpreter before anything else is compiled
grep -q 'BOOTSTRAP' make.log || { echo "guile: no BOOTSTRAP stage in the build" >&2; exit 1; }
make DESTDIR="$OUTPUT_DIR" install
# gdb's auto-load helper lands beside the library as libguile-3.0.so.*-gdb.scm, inside the libs glob
rm -f "$OUTPUT_DIR"/usr/lib/libguile-*-gdb.scm

# installed compiler runs from the staged tree
LD_LIBRARY_PATH="$OUTPUT_DIR/usr/lib" GUILE_LOAD_PATH="$OUTPUT_DIR/usr/share/guile/3.0" \
  GUILE_LOAD_COMPILED_PATH="$OUTPUT_DIR/usr/lib/guile/3.0/ccache" \
  "$OUTPUT_DIR/usr/bin/guile" -c "(exit (string=? (version) \"$MINIMAL_ARG_VERSION\"))"
