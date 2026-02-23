#!/bin/sh
set -e

tar -xof inetutils-2.6.tar.xz
cd inetutils-2.6

./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers

make -j$(nproc)
# tests/hostname.sh fails on arm64: no system hostname binary in PATH
# for comparison, and sethostname syscall blocked by sandbox
if [ "$(uname -m)" != "aarch64" ]; then
  make check
fi
make DESTDIR=$OUTPUT_DIR install
