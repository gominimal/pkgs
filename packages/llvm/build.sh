#!/bin/sh
set -ex

V="$MINIMAL_ARG_VERSION"

tar -xof "llvm-project-$V.src.tar.xz"
cd "llvm-project-$V.src"

sed 's/utility/tool/' -i llvm/utils/FileCheck/CMakeLists.txt

mkdir build
cd build

export CC=clang
export CXX=clang++
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake \
	-D CLANG_CONFIG_FILE_SYSTEM_DIR=/etc/clang \
	-D CLANG_DEFAULT_PIE_ON_LINUX=ON \
	-D CMAKE_BUILD_TYPE=Release \
	-D CMAKE_INSTALL_PREFIX=/usr \
	-D CMAKE_SKIP_INSTALL_RPATH=ON \
	-D LLVM_BINUTILS_INCDIR=/usr/include \
	-D LLVM_INSTALL_UTILS=ON \
	-D LLVM_BUILD_LLVM_DYLIB=ON \
	-D LLVM_ENABLE_FFI=ON \
	-D LLVM_ENABLE_RTTI=ON \
	-D LLVM_INCLUDE_BENCHMARKS=OFF \
	-D LLVM_LINK_LLVM_DYLIB=ON \
	-D LLVM_USE_LINKER=lld \
	-D LLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;lld" \
	-D LLVM_TARGETS_TO_BUILD="all" \
	-W no-dev -G Ninja ../llvm

ninja
DESTDIR=$OUTPUT_DIR ninja 'install/strip'

# The installed tools must report the pinned version.
LD_LIBRARY_PATH="$OUTPUT_DIR/usr/lib" "$OUTPUT_DIR/usr/bin/clang" --version | grep -F "clang version $V"
test "$(LD_LIBRARY_PATH="$OUTPUT_DIR/usr/lib" "$OUTPUT_DIR/usr/bin/llvm-config" --version)" = "$V"
