#!/bin/sh
set -e

tar xf "coreutils-${MINIMAL_ARG_VERSION}.tar.xz"
cd "coreutils-${MINIMAL_ARG_VERSION}"

FORCE_UNSAFE_CONFIGURE=1 ./configure \
    --prefix=/usr \
    --enable-no-install-program=kill,uptime

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
