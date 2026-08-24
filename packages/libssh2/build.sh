#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# Security backports for the ten CVEs fixed upstream after 1.11.1 (see
# build.ncl). Applied by explicit name in Debian's series order, never by glob:
# the order matters where two patches touch one file, and a glob would silently
# reorder or pick up a stray file.
#
# `set -e` plus patch's non-zero exit on a rejected hunk means a stale patch
# ABORTS the build. That is the point — a silently-skipped security patch would
# publish a libssh2 that looks fixed and is not, which is exactly how this
# package came to report 0/0/0 while carrying a live CRITICAL.
patch -Np1 -i "CVE-2026-7598.patch"
patch -Np1 -i "CVE-2025-15661.patch"
patch -Np1 -i "CVE-2026-55199.patch"
patch -Np1 -i "CVE-2026-55200.patch"
# Prerequisite, not a CVE fix: CVE-2025-15661 calls LIBSSH2_UNCONST(), which
# 1.11.1 does not define. Patches clean without it, then fails to compile.
patch -Np1 -i "libssh-unconst-backport.patch"
patch -Np1 -i "CVE-2026-66032.patch"
patch -Np1 -i "CVE-2026-66033.patch"
patch -Np1 -i "CVE-2026-66034.patch"
patch -Np1 -i "CVE-2026-66035.patch"
patch -Np1 -i "CVE-2026-58050.patch"
patch -Np1 -i "CVE-2026-58051.patch"

export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DCRYPTO_BACKEND=OpenSSL

cmake --build build -j$(nproc)
DESTDIR=$OUTPUT_DIR cmake --install build
