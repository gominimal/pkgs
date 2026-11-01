#!/bin/sh
set -ex

tar -xof "zig-${MINIMAL_ARG_VERSION}.tar.xz"
cd "zig-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_PREFIX_PATH="/usr/lib/llvm-22;/usr" \
  -DCMAKE_INSTALL_RPATH=/usr/lib/llvm-22/lib \
  -DZIG_SHARED_LLVM=ON \
  -DZIG_TARGET_MCPU=baseline

ninja -C build
DESTDIR=$OUTPUT_DIR ninja -C build install

# zig links libLLVM.so.22 from the prefixed llvm-22 line; it must find it there
# at run time (RUNPATH), and must not link a second LLVM.
readelf -d "$OUTPUT_DIR/usr/bin/zig" | grep -E 'R(UN)?PATH' | grep -q '/usr/lib/llvm-22/lib'
readelf -d "$OUTPUT_DIR/usr/bin/zig" | grep -q 'NEEDED.*libLLVM.so.22'
if readelf -d "$OUTPUT_DIR/usr/bin/zig" | grep -E 'NEEDED.*libLLVM\.so\.(2[^2]|1)'; then
  echo "zig links an LLVM other than 22" >&2
  exit 1
fi
