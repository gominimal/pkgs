#!/bin/sh
set -ex

tar -xof llvm-21.1.8.src.tar.xz
tar -xof cmake-21.1.8.src.tar.xz
mv cmake-21.1.8.src cmake
tar -xof third-party-21.1.8.src.tar.xz
mv third-party-21.1.8.src third-party
tar -xof clang-21.1.8.src.tar.xz
mv clang-21.1.8.src clang
tar -xof lld-21.1.8.src.tar.xz
mv lld-21.1.8.src lld
tar -xof libunwind-21.1.8.src.tar.xz
mv libunwind-21.1.8.src libunwind
mkdir llvm-21.1.8.src/build
cd llvm-21.1.8.src/build

export CC=gcc
export CXX=g++
case $(uname -m) in
  x86_64)  LLVM_TARGET="X86" ;;
  aarch64) LLVM_TARGET="AArch64" ;;
  *)       LLVM_TARGET="host" ;;
esac

DIST_COMPONENTS="clang;clang-resource-headers;lld"
DIST_COMPONENTS="${DIST_COMPONENTS};llvm-headers;clang-headers"
DIST_COMPONENTS="${DIST_COMPONENTS};cmake-exports;clang-cmake-exports"
DIST_COMPONENTS="${DIST_COMPONENTS};llvm-ar;llvm-ranlib;llvm-nm;llvm-objcopy;llvm-objdump;llvm-strip;llvm-config"

cmake \
	-D CMAKE_BUILD_TYPE=Release \
	-D CMAKE_INSTALL_PREFIX=/usr \
	-D CMAKE_SKIP_INSTALL_RPATH=ON \
	-D LLVM_TARGETS_TO_BUILD="$LLVM_TARGET" \
	-D LLVM_BUILD_LLVM_DYLIB=OFF \
	-D LLVM_LINK_LLVM_DYLIB=OFF \
	-D LLVM_ENABLE_FFI=OFF \
	-D LLVM_ENABLE_RTTI=ON \
	-D LLVM_INCLUDE_BENCHMARKS=OFF \
	-D LLVM_INCLUDE_TESTS=OFF \
	-D LLVM_INCLUDE_EXAMPLES=OFF \
	-D LLVM_INCLUDE_DOCS=OFF \
	-D LLVM_INSTALL_UTILS=ON \
	-D CLANG_DEFAULT_PIE_ON_LINUX=ON \
	-D LLVM_ENABLE_PROJECTS="clang;lld" \
	-D LLVM_DISTRIBUTION_COMPONENTS="$DIST_COMPONENTS" \
	-W no-dev -G Ninja ..

ninja distribution
DESTDIR=$OUTPUT_DIR ninja install-distribution-stripped
