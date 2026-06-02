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
# `make check` can't pass hermetically on ANY arch: tests/hostname.sh
# needs a system hostname binary in PATH to compare against (absent in the
# sandbox) and the sethostname syscall is blocked. The build + install is
# the artifact, and build.ncl's smoketest validates the binary — so skip
# the test suite. (Was arch-gated to skip only arm64, but it failed
# identically on x86_64 — that's the failure we're fixing.)
make DESTDIR=$OUTPUT_DIR install
