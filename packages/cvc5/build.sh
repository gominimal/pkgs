#!/bin/sh
set -eux

SRC=$(pwd)
DEPS="$SRC/_deps"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
REPRO="-ffile-prefix-map=$SRC=/builddir -gno-record-gcc-switches"
export CFLAGS="$MARCH -O2 -pipe $REPRO"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"

# --- CaDiCaL (cvc5's pinned rel-2.1.3-elevate), static, into $DEPS ----------
# Mirrors cvc5's cmake/FindCaDiCaL.cmake ExternalProject: skip ./configure,
# instantiate makefile.in by hand, build only libcadical.a. -fPIC because it is
# linked into libcvc5.so. -DNBUILD: don't include the generated build.hpp,
# which stamps `date` and `uname -n` (the build host's name) into version.o;
# with NBUILD version.cpp falls back to __DATE__/__TIME__ (pinned by the
# sandbox's SOURCE_DATE_EPOCH) and a fixed version string.
tar -xof "$MINIMAL_ARG_CADICAL_COMMIT.tar.gz"
CADICAL="$SRC/cadical-$MINIMAL_ARG_CADICAL_COMMIT"
mkdir -p "$CADICAL/build" "$DEPS/lib" "$DEPS/include/cadical"
sed -e "s,@CXX@,g++," \
    -e "s,@CXXFLAGS@,$MARCH -fPIC -O3 -DNDEBUG -DQUIET -DNBUILD -std=c++11 $REPRO," \
    -e "s,@ROOT@,$CADICAL," \
    -e "s,@CONTRIB@,no," \
    "$CADICAL/makefile.in" > "$CADICAL/build/makefile"
make -C "$CADICAL/build" -j"$(nproc)" libcadical.a
cp "$CADICAL/build/libcadical.a" "$DEPS/lib/"
cp "$CADICAL/src/cadical.hpp" "$CADICAL/src/tracer.hpp" "$DEPS/include/cadical/"

# --- cvc5 -------------------------------------------------------------------
# No network: ENABLE_AUTO_DOWNLOAD=OFF makes every missing dependency a hard
# configure error instead of a download. GMP, SymFPU and pyparsing come from
# the fleet; CaDiCaL from $DEPS above.
# BSD-only: ENABLE_GPL=OFF and every GPL optional library (CLN, GLPK, CoCoA,
# Normaliz) OFF. LibPoly (LGPL, CAD for nonlinear real arithmetic), Kissat,
# CryptoMiniSat, Editline and MPFR are optional and not packaged here: OFF.
# USE_DEFAULT_LINKER=ON: don't let cvc5 pick mold/lld/gold by probing.
cmake -S "$SRC" -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Production \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$DEPS" \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_AUTO_DOWNLOAD=OFF \
  -DENABLE_GPL=OFF \
  -DUSE_CLN=OFF \
  -DUSE_GLPK=OFF \
  -DUSE_COCOA=OFF \
  -DUSE_NORMALIZ=OFF \
  -DUSE_POLY=OFF \
  -DUSE_KISSAT=OFF \
  -DUSE_CRYPTOMINISAT=OFF \
  -DUSE_EDITLINE=OFF \
  -DUSE_MPFR=OFF \
  -DBUILD_BINDINGS_PYTHON=OFF \
  -DBUILD_BINDINGS_JAVA=OFF \
  -DBUILD_DOCS=OFF \
  -DENABLE_UNIT_TESTING=OFF \
  -DUSE_DEFAULT_LINKER=ON \
  > configure.log 2>&1 || { cat configure.log; exit 1; }
cat configure.log

# auto-download OFF already makes a missing dep fatal; also require that the
# pinned CaDiCaL and the fleet SymFPU are the ones configure picked up.
grep -F -- '-- Found CaDiCaL' configure.log
grep -F -- '-- Found SymFPU' configure.log

ninja -C build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" ninja -C build install
