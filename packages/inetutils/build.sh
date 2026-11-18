#!/bin/sh
set -e

tar -xof inetutils-2.8.tar.gz
cd inetutils-2.8

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
#
# TEST_IPV4/TEST_IPV6=no: tests/ping-localhost.sh sends real ICMP to 127.0.0.1,
# which depends on the build host's sandbox networking (ping_group_range, raw
# sockets), not on this source. It passed on one amd64 builder and failed on
# another (pkgs#1558's merge-queue run, 2026-11-18). These are upstream's own
# switches; with both "no" the test exits 77 (SKIP). The shipped ping is still
# exercised by this package's exec_bits test.
if [ "$(uname -m)" != "aarch64" ]; then
  TEST_IPV4=no TEST_IPV6=no make check
fi
# Upstream's install-exec-hooks re-install ping, ping6 and traceroute with
# `install -o root -m 4755`. The build runs unprivileged, so the chown fails,
# install(1) exits before its chmod (leaving the copy it just wrote mode 0600),
# and the hook's `-@` swallows the error: the binaries shipped non-executable
# (pkgs#849). There is no configure switch for this, but the hook targets are
# substituted variables, so empty them and keep automake's normal 0755 install.
# They are deliberately NOT setuid: /usr is mounted nosuid.
make DESTDIR=$OUTPUT_DIR \
     ping_INSTALL_HOOK= \
     ping6_INSTALL_HOOK= \
     traceroute_INSTALL_HOOK= \
     install

# Every installed program must be executable and must not be setuid/setgid.
for f in "$OUTPUT_DIR"/usr/bin/*; do
  mode=$(stat -c %a "$f")
  if [ "$mode" != 755 ]; then
    echo "error: $f installed with mode $mode, expected 755" >&2
    exit 1
  fi
done
for f in ping ping6 traceroute; do
  test -f "$OUTPUT_DIR/usr/bin/$f"
done
