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
# ALWAYS regenerate, do not condition on ./configure being absent.
#
# The release tarball ships an executable `configure`, so the old
# `if [ ! -x ./configure ]` guard skipped autoreconf entirely — and
# libassun-version.patch edits only configure.ac. The patch applied cleanly,
# the build succeeded, and the generated configure still carried the OLD
# Libassuan version requirement. Nothing failed; the patch simply did nothing.
# (CodeRabbit caught this on #721; it appeared when this package moved from the
# GitHub archive, which has no configure, to the release tarball, which does.)
autoreconf -fi
#: doc/Makefile.am renders the module-overview and card-
# architecture diagrams from SVG with ImageMagick's `convert`, which we do not
# package — the targets are BUILT_SOURCES, so make dies with Error 127 before
# anything else. gnupg gates the whole doc subdir behind AM_CONDITIONAL
# (BUILD_DOC), so this is upstream's own switch rather than a hack. Only the
# rendered diagrams and manual are lost; --help and the man pages that matter
# for CLI use are unaffected.
# Three fixes to what `pkgmgr import wolfi` emitted here:
#   * dropped --enable-maintainer-mode. The release tarball's file timestamps
#     make `make` think aclocal.m4 is stale, and maintainer mode then reruns
#     the autotools chain — Error 127 on aclocal.m4. Release tarballs are
#     already bootstrapped; maintainer mode is for git checkouts.
#   * --disable-nlss -> --disable-nls. The original was a typo, and configure
#     only *warns* on unrecognised flags, so NLS was never actually disabled
#     and nothing failed to tell us.
#   * removed a duplicated --prefix=/usr.
./configure --prefix=/usr --enable-deterministic-archives --disable-nls \
            --enable-bzip2 --enable-tofu --enable-scdaemon \
            --enable-ccid-driver --sbindir=/usr/bin
make MAKEINFO=true -j"$(nproc)"
make MAKEINFO=true DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
