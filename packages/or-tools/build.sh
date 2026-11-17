#!/bin/bash
set -euo pipefail

# Pinned, mirrored source for Eigen, which or-tools would otherwise git-clone
# from gitlab.com at build time (see build.ncl, pkgs#1146). FetchContent's
# SOURCE_DIR override skips both the download and or-tools' PATCH_COMMAND, so
# apply or-tools' own patch here, exactly as its PATCH_COMMAND would.
DEPS_SRC="$(pwd)/minimal-deps"
mkdir -p "$DEPS_SRC"
tar -xof eigen-3.4.0.tar.gz -C "$DEPS_SRC"
EIGEN3_SRC="$DEPS_SRC/eigen-3.4.0"
(cd "$EIGEN3_SRC" && git apply --ignore-whitespace "$OLDPWD/patches/eigen3-3.4.0.patch")

# SoPlex, as or-tools patches it (patches/soplex-v8.0.0.patch), stops at
# configure unless the targets Boost::multiprecision and Boost::serialization
# already exist; it never looks for Boost itself. Only or-tools' own Boost build
# (BUILD_Boost=ON) defines them. The boost package has a CMake config for
# serialization and none for multiprecision, which is headers only. Define both
# from the package, in or-tools' top directory right after its project() call,
# so every subdirectory, SoPlex's included, sees them.
BOOST_TARGETS="$DEPS_SRC/minimal-boost-targets.cmake"
cat > "$BOOST_TARGETS" <<'CMAKE'
find_package(Boost 1.70 CONFIG REQUIRED COMPONENTS serialization)
if(NOT TARGET Boost::multiprecision)
  add_library(Boost::multiprecision INTERFACE IMPORTED)
  target_link_libraries(Boost::multiprecision INTERFACE Boost::headers)
endif()
CMAKE

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
  -DBUILD_DEPS=OFF \
  -DBUILD_ZLIB=OFF \
  -DBUILD_BZip2=OFF \
  -DBUILD_absl=OFF \
  -DBUILD_Protobuf=OFF \
  -DBUILD_re2=OFF \
  -DBUILD_Boost=OFF \
  -DBUILD_Eigen3=ON \
  -DBUILD_HIGHS=ON \
  -DBUILD_soplex=ON \
  -DBUILD_SCIP=ON \
  -DBUILD_CoinUtils=ON \
  -DBUILD_Osi=ON \
  -DBUILD_Clp=ON \
  -DBUILD_Cgl=ON \
  -DBUILD_Cbc=ON \
  -DFETCHCONTENT_SOURCE_DIR_EIGEN3="$EIGEN3_SRC" \
  -DCMAKE_PROJECT_ortools_INCLUDE="$BOOST_TARGETS" \
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
[ ! -d "_deps/eigen3-src" ] || { echo "ERROR: FetchContent downloaded eigen3-src instead of the pinned source" >&2; exit 1; }
# Fail closed: the registry's packages were used. FetchContent creates
# _deps/<name>-src for every dependency or-tools builds itself.
for d in zlib bzip2 absl abseil-cpp protobuf re2 boost; do
  [ ! -d "_deps/$d-src" ] || { echo "ERROR: or-tools built its own $d instead of using the package" >&2; exit 1; }
done

# protoc and other build-time tools need to find their shared libs
export LD_LIBRARY_PATH="$(pwd)/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Cap parallelism to nproc/4 (matches packages/foundationdb). or-tools'
# inline-built deps (HiGHS, SCIP, the COIN-OR solvers) link together at peak
# and explode memory at -j32, OOMing the whole build.
JOBS=$(( $(nproc) / 4 ))
[ "$JOBS" -lt 1 ] && JOBS=1

ninja -j"$JOBS"

DESTDIR="$OUTPUT_DIR" ninja install

# Fail closed: nothing of the packages or-tools now depends on was installed
# into this package.
for p in usr/include/boost usr/include/absl usr/include/google/protobuf usr/include/re2 usr/include/zlib.h usr/include/bzlib.h usr/bin/protoc; do
  [ ! -e "$OUTPUT_DIR/$p" ] || { echo "ERROR: $p was installed into or-tools; it belongs to another package" >&2; exit 1; }
done
