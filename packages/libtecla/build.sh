#!/bin/bash
# libtecla — an autoconf configure plus a custom install target
# (install_lib/install_inc/install_man/install_bin) that predates DESTDIR, so we
# redirect the install via the LIBDIR/INCDIR overrides below. Builds in its own
# source tree (it can't build in a subdir). #528.
set -euo pipefail

# libtecla's bundled config.guess/config.sub are from 2003 (pre-aarch64), so
# configure "cannot guess build type". Overwrite them with the modern GNU config
# scripts (fetched as Sources — see build.ncl) before configuring.
cp gnu-config-config.guess libtecla/config.guess
cp gnu-config-config.sub libtecla/config.sub

# The tarball extracts to `./libtecla/` (no strip_prefix), so enter it first.
cd libtecla
chmod +x config.guess config.sub

export CFLAGS="-O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

./configure --prefix=/usr
make

# libtecla's Makefile has no DESTDIR and copies to $(LIBDIR)/$(INCDIR) — which
# configure already substituted to /usr/lib, /usr/include, NOT $(prefix)/… — so
# override those dir vars directly to redirect the install under $OUTPUT_DIR.
# (There's a rule that mkdir's them.) Only the lib + header are wanted; skip the
# demo programs (install_bin) + man pages (install_man).
make install_lib install_inc \
    LIBDIR="$OUTPUT_DIR/usr/lib" \
    INCDIR="$OUTPUT_DIR/usr/include"
