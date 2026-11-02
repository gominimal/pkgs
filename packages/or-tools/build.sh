#!/bin/bash
set -euo pipefail

# Pinned, mirrored sources for the deps or-tools would otherwise git-clone
# from gitlab.com at build time (see build.ncl, pkgs#1146). FetchContent's
# SOURCE_DIR override skips both the download and or-tools' PATCH_COMMAND, so
# apply or-tools' own patches here, exactly as its PATCH_COMMAND would.
DEPS_SRC="$(pwd)/minimal-deps"
mkdir -p "$DEPS_SRC"
tar -xof eigen-3.4.0.tar.gz -C "$DEPS_SRC"
tar -xof bzip2-66c46b8c9436613fd81bc5d03f63a61933a4dcc3.tar.gz -C "$DEPS_SRC"
EIGEN3_SRC="$DEPS_SRC/eigen-3.4.0"
BZIP2_SRC="$DEPS_SRC/bzip2-66c46b8c9436613fd81bc5d03f63a61933a4dcc3"
(cd "$EIGEN3_SRC" && git apply --ignore-whitespace "$OLDPWD/patches/eigen3-3.4.0.patch")
(cd "$BZIP2_SRC" && git apply --ignore-whitespace "$OLDPWD/patches/bzip2.patch")

mkdir build
cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="$CFLAGS"

# SCIP (FetchContent'd by or-tools under USE_SCIP=ON) bundles tinycthread, a C11
# <threads.h> shim that does `#define once_flag pthread_once_t`. glibc 2.43
# surfaces its native once_flag/call_once into SCIP's translation unit, so that
# macro corrupts glibc's `typedef __once_flag once_flag;` into a redefinition of
# pthread_once_t -> "conflicting types" FTBFS. or-tools hard-FORCEs SCIP's
# TPI=tny in its bundled cmake, so a top-level -DTPI=... can't override it; patch
# the source to use SCIP's OpenMP task interface instead (drops tinycthread,
# keeps SCIP parallel + THREADSAFE — SCIP auto-forces THREADSAFE on for any
# non-"none" TPI). libgomp is present from our gcc build. Fails fast at configure
# if OpenMP is somehow absent. glibc-2.43 toolchain-bump fallout, #238.
sed -i 's|set(TPI "tny" CACHE STRING "Scip param" FORCE)|set(TPI "omp" CACHE STRING "Scip param" FORCE)|' ../cmake/dependencies/CMakeLists.txt
grep -q 'set(TPI "omp"' ../cmake/dependencies/CMakeLists.txt \
  || { echo "ERROR: SCIP TPI patch did not apply — or-tools cmake/dependencies/CMakeLists.txt changed upstream"; exit 1; }

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=/usr/lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SKIP_INSTALL_RPATH=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_DEPS=ON \
  -DFETCHCONTENT_SOURCE_DIR_EIGEN3="$EIGEN3_SRC" \
  -DFETCHCONTENT_SOURCE_DIR_BZIP2="$BZIP2_SRC" \
  -DBUILD_CXX=ON \
  -DBUILD_PYTHON=OFF \
  -DBUILD_JAVA=OFF \
  -DBUILD_DOTNET=OFF \
  -DBUILD_SAMPLES=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DUSE_SCIP=ON \
  -DUSE_HIGHS=ON \
  -DUSE_COINOR=ON \
  -DUSE_GLPK=OFF \
  -DUSE_GUROBI=OFF \
  -DUSE_CPLEX=OFF \
  -DUSE_XPRESS=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--unresolved-symbols=ignore-in-shared-libs" \
  ..
# Fail closed: the pinned sources were used, nothing was cloned from GitLab
# (FetchContent creates _deps/<name>-src only when it downloads).
for d in eigen3-src bzip2-src; do
  [ ! -d "_deps/$d" ] || { echo "ERROR: FetchContent downloaded $d instead of the pinned source" >&2; exit 1; }
done

# protoc and other build-time tools need to find their shared libs
export LD_LIBRARY_PATH="$(pwd)/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Cap parallelism to nproc/4 (matches packages/foundationdb). or-tools'
# inline-built deps (protobuf, abseil, HiGHS, eigen) link together at peak
# and explode memory at -j32, OOMing the whole build.
JOBS=$(( $(nproc) / 4 ))
[ "$JOBS" -lt 1 ] && JOBS=1

ninja -j"$JOBS"

DESTDIR="$OUTPUT_DIR" ninja install
