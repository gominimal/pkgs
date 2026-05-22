#!/bin/bash
set -euo pipefail

# Hermetic build: or-tools' cmake/dependencies/CMakeLists.txt uses
# FetchContent_Declare(GIT_REPOSITORY ...) for ~22 deps. In CS we have
# no egress, so the github-hosted ones are pre-staged as Source
# build_deps (see build.ncl). Each extracts to a sibling dir of
# or-tools-*/ at sandbox root, e.g. /abseil-cpp-20250814.1.
#
# Override mechanism: cmake 3.24+ honours FETCHCONTENT_SOURCE_DIR_<NAME>
# (UPPERCASE) to redirect a fetch to a local dir; or-tools requires 3.24
# so this is safe. We pass each as -D to cmake (not env) because one of
# the names (protobuf-matchers) contains a hyphen, which bash refuses
# in env-var names but cmake's variable system accepts.
#
# The 3 non-staged ones are disabled at configure time:
#   BZip2  (gitlab, branch ref)        -> -DBUILD_BZip2=OFF
#   Eigen3 (gitlab)                    -> -DBUILD_Eigen3=OFF
#   pybind11 / pybind11_abseil /       -> indirectly: BUILD_PYTHON=OFF
#     pybind11_protobuf                   (pybind11* are gated on it)
# BUILD_ZLIB is OFF too — we use the system zlib build_dep instead.

# Resolve each extracted dir. Pre-staged tarballs extract to
# <repo>-<tag> by github archive convention. Fast-fail if any
# pre-stage is missing — friendlier than a cmake fetch attempt that
# 404s in the offline sandbox.
resolve_dir() {
    local pattern="$1"
    local matched
    matched=$(ls -d "$pattern" 2>/dev/null | head -1)
    if [ -z "$matched" ]; then
        echo "FAIL: no extracted dir matches $pattern" >&2
        ls -1d /*-* 2>/dev/null | head -30 >&2
        exit 1
    fi
    echo "$matched"
}

ZLIB_DIR=$(resolve_dir "/ZLIB-1.3.1")
ABSL_DIR=$(resolve_dir "/abseil-cpp-20250814.1")
PROTOBUF_DIR=$(resolve_dir "/protobuf-33.1")
RE2_DIR=$(resolve_dir "/re2-2025-08-12")
PYBIND11_ABSEIL_DIR=$(resolve_dir "/pybind11_abseil-202402.0")
PYBIND11_PROTOBUF_DIR=$(resolve_dir "/pybind11_protobuf-f02a2b7653bc50eb5119d125842a3870db95d251")
GLPK_DIR=$(resolve_dir "/GLPK-5.0.1")
HIGHS_DIR=$(resolve_dir "/HiGHS-1.12.0")
BOOST_DIR=$(resolve_dir "/boost-boost-1.87.0")
SOPLEX_DIR=$(resolve_dir "/soplex-8.0.0")
SCIP_DIR=$(resolve_dir "/scip-10.0.0")
COINUTILS_DIR=$(resolve_dir "/CoinUtils-cmake-2.11.12")
OSI_DIR=$(resolve_dir "/Osi-cmake-0.108.11")
CLP_DIR=$(resolve_dir "/Clp-cmake-1.17.10")
CGL_DIR=$(resolve_dir "/Cgl-cmake-0.60.9")
CBC_DIR=$(resolve_dir "/Cbc-cmake-2.10.12")
GOOGLETEST_DIR=$(resolve_dir "/googletest-1.17.0")
PROTOBUF_MATCHERS_DIR=$(resolve_dir "/protobuf-matchers-0.1.1")
BENCHMARK_DIR=$(resolve_dir "/benchmark-1.9.2")

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

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=/usr/lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SKIP_INSTALL_RPATH=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_DEPS=ON \
  -DBUILD_CXX=ON \
  -DBUILD_PYTHON=OFF \
  -DBUILD_JAVA=OFF \
  -DBUILD_DOTNET=OFF \
  -DBUILD_SAMPLES=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_BZip2=OFF \
  -DBUILD_Eigen3=OFF \
  -DBUILD_ZLIB=OFF \
  -DUSE_SCIP=ON \
  -DUSE_HIGHS=ON \
  -DUSE_COINOR=ON \
  -DUSE_GLPK=OFF \
  -DUSE_GUROBI=OFF \
  -DUSE_CPLEX=OFF \
  -DUSE_XPRESS=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--unresolved-symbols=ignore-in-shared-libs" \
  -DFETCHCONTENT_SOURCE_DIR_ZLIB="${ZLIB_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_ABSL="${ABSL_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_PROTOBUF="${PROTOBUF_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_RE2="${RE2_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_PYBIND11_ABSEIL="${PYBIND11_ABSEIL_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_PYBIND11_PROTOBUF="${PYBIND11_PROTOBUF_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_GLPK="${GLPK_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_HIGHS="${HIGHS_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_BOOST="${BOOST_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_SOPLEX="${SOPLEX_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_SCIP="${SCIP_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_COINUTILS="${COINUTILS_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_OSI="${OSI_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_CLP="${CLP_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_CGL="${CGL_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_CBC="${CBC_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST="${GOOGLETEST_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_PROTOBUF-MATCHERS="${PROTOBUF_MATCHERS_DIR}" \
  -DFETCHCONTENT_SOURCE_DIR_BENCHMARK="${BENCHMARK_DIR}" \
  ..

# protoc and other build-time tools need to find their shared libs
export LD_LIBRARY_PATH="$(pwd)/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Cap parallelism to nproc/4 (matches packages/foundationdb). or-tools'
# inline-built deps (protobuf, abseil, HiGHS) link together at peak
# and explode memory at -j32, OOMing the whole build.
JOBS=$(( $(nproc) / 4 ))
[ "$JOBS" -lt 1 ] && JOBS=1

ninja -j"$JOBS"

DESTDIR="$OUTPUT_DIR" ninja install
