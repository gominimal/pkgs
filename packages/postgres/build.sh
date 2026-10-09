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
            --with-zstd

# TODO: --with-lz4 once we package lz4

make -j$(nproc)
# make check # Needs user lookup to function
make DESTDIR=$OUTPUT_DIR install
# contrib: the extensions apps enable as a matter of course (pg_trgm,
# pgcrypto, pg_stat_statements, citext, hstore, unaccent, ...). Without them
# `enable_extension` in a Rails schema fails with "extension ... is not
# available".
make -C contrib -j$(nproc)
make -C contrib DESTDIR=$OUTPUT_DIR install
