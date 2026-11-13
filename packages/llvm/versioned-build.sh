#!/bin/sh
# Build script for the prefixed llvm-<major> packages (see versioned.ncl).
# Mirrors ../llvm/build.sh's configuration; installs under /usr/lib/llvm-<major>.
set -ex

V="$MINIMAL_ARG_VERSION"
M="$MINIMAL_ARG_MAJOR"
PREFIX="/usr/lib/llvm-$M"

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

# Unlike ../llvm, no CMAKE_SKIP_INSTALL_RPATH: binaries under the prefix rely on LLVM's
# default $ORIGIN/../lib RPATH to find libLLVM / libclang. No CLANG_CONFIG_FILE_SYSTEM_DIR:
# /etc/clang belongs to the unprefixed llvm.
cmake \
	-D CLANG_DEFAULT_PIE_ON_LINUX=ON \
	-D CMAKE_BUILD_TYPE=Release \
	-D CMAKE_INSTALL_PREFIX="$PREFIX" \
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

# Fail closed: nothing may land outside the prefix (that is the whole point of these packages).
# The one exception is a bare usr/lib64 symlink, which the build-bot output dir carries
# (merged-usr scaffold, not installed by LLVM; no output glob ships it). A file written
# THROUGH it would still show up below as a file outside the prefix.
if [ -L "$OUTPUT_DIR/usr/lib64" ]; then ls -ld "$OUTPUT_DIR/usr/lib64"; fi
stray=$(cd "$OUTPUT_DIR" && find . \( -type f -o -type l \) ! -path ".$PREFIX/*" ! \( -type l -path ./usr/lib64 \) | head -20)
if [ -n "$stray" ]; then
  echo "ERROR: files installed outside $PREFIX:" >&2
  echo "$stray" >&2
  exit 1
fi

# The installed tools must run from the prefix (proves the $ORIGIN RPATH resolves).
"$OUTPUT_DIR$PREFIX/bin/clang" --version | grep -F "clang version $V"
test "$("$OUTPUT_DIR$PREFIX/bin/llvm-config" --version)" = "$V"
