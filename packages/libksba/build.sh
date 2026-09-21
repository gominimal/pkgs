#!/bin/sh
# Imported from Wolfi `libgpg-error` (1.61, autotools) by pkgmgr import wolfi.
# Configure opts below were ported from the Wolfi recipe's `with.opts`.
# TODO: REVIEWER — confirm they apply to a from-source (non-apk) build.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
if [ ! -x ./configure ]; then autoreconf -fi; fi
./configure --prefix=/usr --enable-deterministic-archives --disable-nls --enable-static --sysconfdir=/etc --enable-maintainer-mode
make MAKEINFO=true -j"$(nproc)"
make MAKEINFO=true DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
