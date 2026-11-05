#!/bin/sh
set -e

tar -xof "postgresql-${MINIMAL_ARG_VERSION}.tar.gz"
cd "postgresql-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                       \
            --with-openssl                      \
            --with-zstd                         \
            --with-lz4

# world-bin is the server plus contrib (pgcrypto, pg_trgm, hstore, ...),
# but not the docs.
make -j$(nproc) world-bin
# make check # Needs user lookup to function
make DESTDIR=$OUTPUT_DIR install-world-bin

# contrib silently skips pgcrypto and sslinfo when configure did not
# pick up OpenSSL, so fail here rather than ship a postgres without them.
test -e "$OUTPUT_DIR/usr/lib/postgresql/pgcrypto.so"
test -e "$OUTPUT_DIR/usr/lib/postgresql/sslinfo.so"
