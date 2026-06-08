#!/bin/sh
set -e

tar -xof "v${MINIMAL_ARG_VERSION}.tar.gz"
cd "lean4-${MINIMAL_ARG_VERSION}"

# Hermetic build: lean's CMakeLists.txt uses ExternalProject_add with
# GIT_REPOSITORY for cadical, libuv, mimalloc. In CS we have no egress,
# so those three are pre-staged as Source{extract=true} deps in build.ncl.
# The builder hardlinks build_deps (working_inputs) into the build CWD, so
# they land at /build/<archive-top-dir> — siblings of the extracted
# lean4-*/ — NOT at /. github tarball dir names vary (<repo>-<tag> vs
# <owner>-<repo>-<sha>), so discover each by glob under /build.
CADICAL_DIR=$(ls -d /build/cadical-* 2>/dev/null | head -1)
MIMALLOC_DIR=$(ls -d /build/*mimalloc-* 2>/dev/null | head -1)
LIBUV_DIR=$(ls -d /build/libuv-* 2>/dev/null | head -1)
if [ -n "$CADICAL_DIR" ] && [ -n "$MIMALLOC_DIR" ] && [ -n "$LIBUV_DIR" ]; then
    # cadical: BUILD_IN_SOURCE is ON and src/cadical.mk links the binary to
    # the RELATIVE path ../../cadical, which lean then expects at
    # <prefix>/cadical (CMAKE_BINARY_DIR/cadical). Overriding SOURCE_DIR to
    # /build/cadical-rel-2.1.2 sent ../../cadical to /cadical (rootfs root,
    # read-only) AND misplaced the binary. So do NOT relocate SOURCE_DIR —
    # keep the default (<prefix>/src/cadical) and replace the git download
    # with a copy of the pre-staged source into it. Then ../../cadical lands
    # at <prefix>/cadical exactly where lean looks, on a writable path.
    sed -i \
        -e "/ExternalProject_add(cadical/,/GIT_TAG/{
            /GIT_REPOSITORY/d
            s|GIT_TAG rel-2.1.2|DOWNLOAD_COMMAND \${CMAKE_COMMAND} -E copy_directory ${CADICAL_DIR} <SOURCE_DIR>|
        }" \
        CMakeLists.txt

    # mimalloc: lean's CMakeLists.txt:581 `file COPY`s mimalloc.h from the
    # DEFAULT ExternalProject path (<prefix>/src/mimalloc/include/), so
    # relocating SOURCE_DIR makes that COPY fail "No such file". Same fix as
    # cadical above: copy_directory the staged source INTO <SOURCE_DIR> (the
    # default path) rather than pointing the build elsewhere.
    sed -i \
        -e "/ExternalProject_add(mimalloc/,/GIT_TAG/{
            /GIT_REPOSITORY/d
            s|GIT_TAG v2.2.3|DOWNLOAD_COMMAND \${CMAKE_COMMAND} -E copy_directory ${MIMALLOC_DIR} <SOURCE_DIR>|
        }" \
        CMakeLists.txt

    # libuv: lives in src/CMakeLists.txt (and stage0/src/CMakeLists.txt
    # uses the same block when stage0 rebuilds)
    for f in src/CMakeLists.txt stage0/src/CMakeLists.txt; do
        sed -i \
            -e "/ExternalProject_add(libuv/,/GIT_TAG/{
                /GIT_REPOSITORY/d
                /Sync version with flake.nix/d
                s|GIT_TAG v1.48.0|SOURCE_DIR ${LIBUV_DIR}|
            }" \
            "$f"
    done

    echo "[lean build.sh] Hermetic submodule patches applied (cadical=$CADICAL_DIR mimalloc=$MIMALLOC_DIR libuv=$LIBUV_DIR)."
else
    # Fail loud rather than silently fall through to a doomed offline git
    # clone — print what IS under /build so the next attempt can adjust.
    echo "[lean build.sh] FATAL: submodule sources not found under /build (cadical=$CADICAL_DIR mimalloc=$MIMALLOC_DIR libuv=$LIBUV_DIR)" >&2
    echo "[lean build.sh] /build contains:" >&2
    ls -d /build/*/ >&2 2>/dev/null || true
    exit 1
fi

# Lake install detection fails in the CS sandbox: stage0/bin/lake builds stage1's
# stdlib and dies "could not detect the configuration of the Lake installation"
# (unknownLakeInstall) — its IO.appPath joint-home probe returns none in-sandbox,
# and the fallbacks can't find the toolchain-layout install. Two-part fix:
#
# (1) Patch src/lake so the JOINT-home detector also honors LEAN_SYSROOT, appended
#     AFTER the appPath probe so appPath still wins when it works (stage-correct).
#     This covers any lake BUILT from src — i.e. stage1's lake building stage2, if
#     the bootstrap goes that far. (The stage0 lake is from the committed C
#     snapshot, NOT src/lake, so this alone does NOT fix the failing stage0 lake —
#     see part (2) below.) Portable sed (@ delim avoids the |> conflict).
sed -i 's@^        return appDir.parent$@        return appDir.parent\
  if let some sr ← IO.getEnv "LEAN_SYSROOT" then\
    if (← ((sr : FilePath) / "bin" / "lean" |>.addExtension FilePath.exeExtension).pathExists) then\
      return some (sr : FilePath)@' \
    src/lake/Lake/Config/InstallPath.lean

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

cmake --preset release

# (2) The lake that actually FAILS is stage0/bin/lake (committed C snapshot, not
#     the src patched above). Route it through the env fallbacks its findInstall?
#     else-branch already supports: LEAN_SYSROOT -> findLeanInstall?, and LAKE_HOME
#     -> findLakeInstall?. LakeInstall under LAKE_HOME expects its lib/bin at
#     <home>/.lake/build/{lib,bin}, but stage0's toolchain layout puts them at
#     <home>/{lib/lean,bin}; symlink the .lake/build paths onto the real ones so
#     lake loads Lake.olean from the toolchain tree. Created dangling pre-build;
#     they resolve once `make` populates stage0/. (If a CS build still fails here:
#     olean-not-found => the ExternalProject wiped the symlinks; still
#     unknownLakeInstall => stage0 lake ignores these env vars.)
S0="$(pwd)/build/release/stage0"
mkdir -p "$S0/.lake/build"
ln -sfn ../../bin "$S0/.lake/build/bin"
ln -sfn ../../lib/lean "$S0/.lake/build/lib"
export LEAN_SYSROOT="$S0"
export LAKE_HOME="$S0"

make -C build/release -j$(nproc)

# Install from stage1 output
STAGE=build/release/stage1

mkdir -p "$OUTPUT_DIR/usr/bin"
cp "$STAGE/bin/lean" "$STAGE/bin/lake" "$STAGE/bin/leanc" "$OUTPUT_DIR/usr/bin/"
# leanchecker is optional but useful
if [ -f "$STAGE/bin/leanchecker" ]; then
  cp "$STAGE/bin/leanchecker" "$OUTPUT_DIR/usr/bin/"
fi
if [ -f "$STAGE/bin/leanmake" ]; then
  cp "$STAGE/bin/leanmake" "$OUTPUT_DIR/usr/bin/"
fi

# Libraries are under lib/lean/
mkdir -p "$OUTPUT_DIR/usr/lib/lean"
cp -a "$STAGE/lib/lean/"*.a "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true
cp -a "$STAGE/lib/lean/"*.so* "$OUTPUT_DIR/usr/lib/lean/" 2>/dev/null || true
# Copy olean files and other lean lib data
for d in "$STAGE/lib/lean/"*/; do
  [ -d "$d" ] && cp -r "$d" "$OUTPUT_DIR/usr/lib/lean/"
done

if [ -d "$STAGE/include" ]; then
  mkdir -p "$OUTPUT_DIR/usr/include"
  cp -r "$STAGE/include/"* "$OUTPUT_DIR/usr/include/"
fi
