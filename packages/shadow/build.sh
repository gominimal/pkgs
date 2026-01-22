#!/bin/sh
set -e

tar xfo "shadow-${MINIMAL_ARG_VERSION}.tar.xz"
cd "shadow-${MINIMAL_ARG_VERSION}"

sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\\.5 / /'   {} \;

sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs

mkdir -p "$OUTPUT_DIR/usr/bin"
touch "$OUTPUT_DIR/usr/bin/passwd"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --without-libbsd    \
            --with-group-name-max-length=32

make -j$(nproc)
make exec_prefix=/usr DESTDIR="$OUTPUT_DIR" install
