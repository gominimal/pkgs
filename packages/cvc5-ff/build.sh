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
# FindCoCoA.cmake reads the CoCoALib version from a `COCOALIB_VERSION=` line
# in CoCoA/library.H, a line CoCoALib's generated unified header does not
# have (it carries `// Unified header file for CoCoALib version 0.99850`).
# Upstream always builds its own ExternalProject, so this system-library path
# goes unexercised: the version comes back empty, fails the `>= 0.99711`
# check, and with auto-download OFF configure stops. Point the regex at the
# line that exists; the `[0-9]+\.[0-9]+` match after it yields 0.99850.
grep -qF 'REGEX "^COCOALIB_VERSION=.*"' cmake/FindCoCoA.cmake
sed -i 's|REGEX "^COCOALIB_VERSION=\.\*"|REGEX "^// Unified header file for CoCoALib version [0-9.]+$"|' cmake/FindCoCoA.cmake
grep -qF 'REGEX "^// Unified header file for CoCoALib version [0-9.]+$"' cmake/FindCoCoA.cmake

# As packages/cvc5 (see the comments there), except:
#  - ENABLE_GPL=ON and USE_COCOA=ON: finite fields. The fleet's cocoalib is
#    static and carries cvc5's trace patch, so it passes FindCoCoA's
#    try_compile probe for that patch. CLN, GLPK and Normaliz (also GPL) stay
#    OFF: QF_FF doesn't use them.
#  - CMAKE_INSTALL_LIBDIR=lib/cvc5-ff: the now-GPL libcvc5 and libcvc5parser
#    go in a private directory. cvc5 sets the binary's RUNPATH to
#    $ORIGIN/../$CMAKE_INSTALL_LIBDIR itself.
cmake -S "$SRC" -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Production \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib/cvc5-ff \
  -DCMAKE_PREFIX_PATH="$DEPS" \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_AUTO_DOWNLOAD=OFF \
  -DENABLE_GPL=ON \
  -DUSE_CLN=OFF \
  -DUSE_GLPK=OFF \
  -DUSE_COCOA=ON \
  -DUSE_NORMALIZ=OFF \
  -DUSE_POLY=ON \
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

# Every dependency is the one we supply ("Found", not "Building").
grep -F -- '-- Found CaDiCaL' configure.log
grep -F -- '-- Found SymFPU' configure.log
grep -F -- '-- Found Poly 0.2.1' configure.log
grep -F -- '-- Found CoCoA 0.99850' configure.log

ninja -C build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" ninja -C build install

# Ship the program only, under its own name. The headers and the CMake
# package config go, so nothing can build against the GPL libraries.
mv "$OUTPUT_DIR/usr/bin/cvc5" "$OUTPUT_DIR/usr/bin/cvc5-ff"
rm -r "$OUTPUT_DIR/usr/include" "$OUTPUT_DIR/usr/lib/cvc5-ff/cmake"
test "$(ls -A "$OUTPUT_DIR/usr/bin")" = cvc5-ff
ls "$OUTPUT_DIR"/usr/lib/cvc5-ff/libcvc5.so* "$OUTPUT_DIR"/usr/lib/cvc5-ff/libcvc5parser.so*
# The binary finds its private libraries relative to itself: check the
# dynamic section, then prove it by running the not-yet-installed copy.
dyn=$(readelf -d "$OUTPUT_DIR/usr/bin/cvc5-ff")
echo "$dyn" | grep -E '\((RUNPATH|RPATH)\)'
echo "$dyn" | grep -Eq '\((RUNPATH|RPATH)\).*\[\$(\{ORIGIN\}|ORIGIN)/\.\./lib/cvc5-ff\]'
"$OUTPUT_DIR/usr/bin/cvc5-ff" --version | head -1
