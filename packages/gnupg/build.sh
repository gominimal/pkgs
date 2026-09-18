#!/bin/sh
# Imported from Wolfi `gnupg` (2.4.9, autotools) by pkgmgr import wolfi.
# Configure opts below were ported from the Wolfi recipe's `with.opts`.
# TODO: REVIEWER — confirm they apply to a from-source (non-apk) build.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
# Wolfi patches (applied before configure).
patch -Np1 -i "libassun-version.patch"
patch -Np1 -i "0010-avoid-beta-warning.patch"
patch -Np1 -i "0210-dirmngr-hkp-avoid-potential-race-condition-when-some-host-die.patch"
patch -Np1 -i "fix-i18n.patch"
patch -Np1 -i "make-aes-default-for-fips.patch"
if [ ! -x ./configure ]; then autoreconf -fi; fi
./configure --prefix=/usr --enable-deterministic-archives --prefix=/usr --disable-nls --disable-docs --enable-bzip2 --enable-tofu --enable-scdaemon --enable-ccid-driver --enable-maintainer-mode --sbindir=/usr/bin
make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
