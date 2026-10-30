#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

PREFIX=/usr/lib/openssl-3.5

# Same flags as packages/openssl except the prefix. OPENSSLDIR stays /etc/ssl so the CA
# store and openssl.cnf are shared; MODULESDIR / ENGINESDIR follow libdir into $PREFIX/lib.
./config --prefix="$PREFIX"     \
         --openssldir=/etc/ssl  \
         --libdir=lib           \
         shared                 \
         zlib-dynamic

make -j$(nproc)
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
# install_sw = install_dev install_engines install_modules install_runtime: libraries,
# headers, pkgconfig, cmake, engines, modules and programs. It does not write OPENSSLDIR
# (that is install_ssldirs) or the docs.
make DESTDIR="$OUTPUT_DIR" install_sw

P="$OUTPUT_DIR$PREFIX"
# The CLI belongs to packages/openssl (/usr/bin/openssl, 4.x). Nothing under bin/ is an
# output; delete it so the tree holds only what the outputs capture.
find "$P/bin" -mindepth 1 -delete
rmdir "$P/bin"
find "$P/lib" -maxdepth 1 -name '*.a' -delete

# Runtime sonames onto the default loader path; the dev tree keeps link-time symlinks.
mkdir -p "$OUTPUT_DIR/usr/lib"
for l in libssl libcrypto; do
  mv "$P/lib/$l.so.3" "$OUTPUT_DIR/usr/lib/$l.so.3"
  ln -sfn "../../$l.so.3" "$P/lib/$l.so"
done

# Fail closed on the layout the outputs and consumers rely on.
test -e "$OUTPUT_DIR/usr/lib/libssl.so.3"
test -e "$OUTPUT_DIR/usr/lib/libcrypto.so.3"
test -e "$P/lib/libssl.so"
test -e "$P/include/openssl/opensslv.h"
test -e "$P/lib/pkgconfig/openssl.pc"
test -e "$P/lib/ossl-modules/legacy.so"
grep -qE '^# *define OPENSSL_VERSION_MINOR +5$' "$P/include/openssl/opensslv.h"
