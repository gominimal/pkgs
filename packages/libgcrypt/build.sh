#!/bin/sh
# Imported from Wolfi `libgcrypt` (1.12.4, autotools) by pkgmgr import wolfi.
# Configure opts below were ported from the Wolfi recipe's `with.opts`.
# TODO: REVIEWER — confirm they apply to a from-source (non-apk) build.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
if [ ! -x ./configure ]; then autoreconf -fi; fi
# NOTE: the importer emitted `-O0" -O0" -O0"` here, mangling Wolfi's
# with.opts into unbalanced quotes (build.sh then died with "unexpected EOF
# while looking for matching \""). Rewritten by hand.
./configure --prefix=/usr --enable-deterministic-archives --disable-doc \
            --with-libgpg-error-prefix=/usr
make MAKEINFO=true -j"$(nproc)"
make MAKEINFO=true DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
