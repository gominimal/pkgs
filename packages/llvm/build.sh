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
tar -xof compiler-rt-21.1.8.src.tar.xz
mv compiler-rt-21.1.8.src compiler-rt

sed 's/utility/tool/' -i llvm-21.1.8.src/utils/FileCheck/CMakeLists.txt

mkdir llvm-21.1.8.src/build
cd llvm-21.1.8.src/build

export CC=clang
export CXX=clang++
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
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
	-D LLVM_ENABLE_PROJECTS="clang;compiler-rt;lld" \
	-D LLVM_TARGETS_TO_BUILD="all" \
	-W no-dev -G Ninja ..

ninja
DESTDIR=$OUTPUT_DIR ninja 'install/strip'
