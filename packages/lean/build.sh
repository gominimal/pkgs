#!/bin/sh
set -e

tar -xof "v${MINIMAL_ARG_VERSION}.tar.gz"
cd "lean4-${MINIMAL_ARG_VERSION}"

# Hermetic build: lean's CMakeLists.txt uses ExternalProject_add with
# GIT_REPOSITORY for cadical, libuv, mimalloc. In CS we have no egress,
# so those three are pre-staged as Source build_deps in build.ncl. Each
# extracts to a sibling dir of lean4-*/ in the sandbox rootfs; we sed-
# patch the CMakeLists to use SOURCE_DIR instead. mimalloc's dir name
# is sha-prefixed by github's tarball API; resolve with a glob.
MIMALLOC_DIR=$(ls -d /microsoft-mimalloc-* 2>/dev/null | head -1)
if [ -n "$MIMALLOC_DIR" ]; then
    # cadical: replace GIT_REPOSITORY + GIT_TAG with SOURCE_DIR
    sed -i \
        -e '/ExternalProject_add(cadical/,/GIT_TAG/{
            /GIT_REPOSITORY/d
            s|GIT_TAG rel-2.1.2|SOURCE_DIR /cadical-rel-2.1.2|
        }' \
        ../CMakeLists.txt 2>/dev/null || true
    # The CMakeLists is inside the cwd; the path adjusts inside cd later.
    # Re-apply for the actual file (cwd is now lean4-*).
    sed -i \
        -e '/ExternalProject_add(cadical/,/GIT_TAG/{
            /GIT_REPOSITORY/d
            s|GIT_TAG rel-2.1.2|SOURCE_DIR /cadical-rel-2.1.2|
        }' \
        CMakeLists.txt

    # mimalloc
    sed -i \
        -e "/ExternalProject_add(mimalloc/,/GIT_TAG/{
            /GIT_REPOSITORY/d
            s|GIT_TAG v2.2.3|SOURCE_DIR ${MIMALLOC_DIR}|
        }" \
        CMakeLists.txt

    # libuv: lives in src/CMakeLists.txt (and stage0/src/CMakeLists.txt
    # uses the same block when stage0 rebuilds)
    for f in src/CMakeLists.txt stage0/src/CMakeLists.txt; do
        sed -i \
            -e '/ExternalProject_add(libuv/,/GIT_TAG/{
                /GIT_REPOSITORY/d
                /Sync version with flake.nix/d
                s|GIT_TAG v1.48.0|SOURCE_DIR /libuv-1.48.0|
            }' \
            "$f"
    done

    echo "[lean build.sh] Hermetic submodule patches applied."
else
    echo "[lean build.sh] WARN: /microsoft-mimalloc-* not found, falling back to online build" >&2
fi

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
