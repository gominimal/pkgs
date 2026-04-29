#!/bin/sh
set -ex

LLVM_VERSION="${MINIMAL_ARG_VERSION}"

tar -xof "llvm-${LLVM_VERSION}.src.tar.xz"
tar -xof "cmake-${LLVM_VERSION}.src.tar.xz"
mv "cmake-${LLVM_VERSION}.src" cmake
tar -xof "third-party-${LLVM_VERSION}.src.tar.xz"
mv "third-party-${LLVM_VERSION}.src" third-party
tar -xof "clang-${LLVM_VERSION}.src.tar.xz"
mv "clang-${LLVM_VERSION}.src" clang
tar -xof "clang-tools-extra-${LLVM_VERSION}.src.tar.xz"
mv "clang-tools-extra-${LLVM_VERSION}.src" clang-tools-extra
tar -xof "lld-${LLVM_VERSION}.src.tar.xz"
mv "lld-${LLVM_VERSION}.src" lld
tar -xof "libunwind-${LLVM_VERSION}.src.tar.xz"
mv "libunwind-${LLVM_VERSION}.src" libunwind
tar -xof "compiler-rt-${LLVM_VERSION}.src.tar.xz"
mv "compiler-rt-${LLVM_VERSION}.src" compiler-rt

sed 's/utility/tool/' -i "llvm-${LLVM_VERSION}.src/utils/FileCheck/CMakeLists.txt"

mkdir "llvm-${LLVM_VERSION}.src/build"
cd "llvm-${LLVM_VERSION}.src/build"

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
	-D LLVM_TARGETS_TO_BUILD="X86;AArch64;WebAssembly;ARM;RISCV" \
	-D LLVM_PARALLEL_LINK_JOBS=2 \
	-W no-dev -G Ninja ..

ninja
DESTDIR=$OUTPUT_DIR ninja 'install/strip'
