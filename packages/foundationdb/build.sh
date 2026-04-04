#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Use shared OpenSSL (static libs not available in this environment)
sed -i 's/set(OPENSSL_USE_STATIC_LIBS TRUE)/set(OPENSSL_USE_STATIC_LIBS FALSE)/' cmake/FDBComponents.cmake

# Disable flowbench (not needed for production builds)
sed -i '/add_subdirectory(flowbench/s/^/#/' CMakeLists.txt

# Fix toml11 compatibility with CMake 4.x (old cmake_minimum_required)
sed -i '/-Dtoml11_BUILD_TEST/a\      -DCMAKE_POLICY_VERSION_MINIMUM:STRING=3.5' cmake/FDBComponents.cmake

cmake -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_DOCUMENTATION=OFF \
  -DBUILD_PYTHON_BINDING=OFF \
  -DBUILD_JAVA_BINDING=OFF \
  -DBUILD_GO_BINDING=OFF \
  -DBUILD_RUBY_BINDING=OFF \
  -DSSD_ROCKSDB_EXPERIMENTAL=OFF \
  -DBUILD_AWS_BACKUP=OFF \
  -DBUILD_TESTING=OFF \
  -DUSE_JEMALLOC=OFF

# Create stub Python binding files so copy_binding_output_files target succeeds
# (Python bindings are disabled but the binding tester still tries to copy them)
mkdir -p build/bindings/python/fdb
touch build/bindings/python/fdb/fdboptions.py
touch build/bindings/python/fdb/apiversion.py

JOBS=$(( $(nproc) / 4 ))
[ "$JOBS" -lt 1 ] && JOBS=1

ninja -C build -j"$JOBS"
DESTDIR="$OUTPUT_DIR" ninja -C build -j"$JOBS" install
