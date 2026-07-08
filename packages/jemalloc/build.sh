#!/bin/sh
# Imported from Wolfi `jemalloc` (5.3.1, autotools) by pkgmgr import-wolfi.
set -eu
# gcc-16 build fix (upstream cherry-pick 1a15fe33 / #2900) — before autogen so
# the regenerated configure picks up the new JEMALLOC_HAVE_CXX_EXCEPTIONS check.
patch -Np1 -i "jemalloc-gcc16-cxx-exceptions.patch"
# The git-archive has no VERSION file; write the real version so configure
# stamps 5.3.1 (not the "0.0.0-...-missing_version" fallback) into the outputs.
echo "$MINIMAL_ARG_VERSION" > VERSION
if [ ! -x ./configure ]; then autoreconf -fi; fi
./configure --prefix=/usr
make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
