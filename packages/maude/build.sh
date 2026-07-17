#!/bin/bash
# Maude — C++ rewriting engine. The github tag archive is raw git source (no
# generated build scripts), so autoreconf first. Maude's INSTALL links 3rd-party
# libs STATICALLY (and hides the .so's to force it); minimal ships them
# --disable-static (shared only), so we link DYNAMICALLY — configure's default
# *_LIB flags already point at the shared libs (see below). CVC4 + Yices2
# disabled to start. See pkgmgr-rs#528.
set -ex

export CFLAGS="-O2 -pipe -fno-stack-protector -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none -L/usr/lib"
export CPPFLAGS="-I/usr/include"

# The tag archive has no generated ./configure — build it.
autoreconf -i

# Maude's configure defaults the link vars to the right DYNAMIC `-l` flags when
# they're unset — GMP_LIBS="-lgmpxx -lgmp", LIBSIGSEGV_LIB="-lsigsegv",
# BUDDY_LIB="-lbdd" — and AUTO-DETECTS TECLA_LIBS="-ltecla -lncurses" (tecla needs
# a terminfo lib; hardcoding "-ltecla" would drop it). So we pass none of them and
# just disable the SMT backends (not packaged). --enable-compiler is experimental
# and not needed for tamarin's use — leave it off (default).
./configure \
    --prefix=/usr \
    --with-cvc4=no \
    --with-yices2=no

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# Smoke-test: maude's compiled-in prelude path is the runtime /usr/share (absent
# in the build sandbox), so point MAUDE_LIB at the freshly-installed share dir
# and REQUIRE a version print. The sandbox hides stdout, but a nonzero exit here
# fails the build — so this genuinely proves the binary links + finds its
# prelude, not just that `make install` ran. (#528)
export MAUDE_LIB="$OUTPUT_DIR/usr/share"
ver_out="$("$OUTPUT_DIR/usr/bin/maude" --version 2>&1 || true)"
echo "maude --version → $ver_out"
echo "$ver_out" | grep -qE "3\.5" \
    || { echo "smoke test FAILED: maude did not print its version (got: '$ver_out')" >&2; exit 1; }
