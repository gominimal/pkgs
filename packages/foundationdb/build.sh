#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
# OpenSSL 3.5 LTS from packages/openssl-3.5, not the 4.x in /usr/include (see build.ncl).
# The -I keeps every translation unit on the 3.5 headers, including ones that include
# <openssl/...> without linking OpenSSL::SSL (boost.asio).
OSSL3=/usr/lib/openssl-3.5
export CFLAGS="$CFLAGS -I$OSSL3/include"
export CXXFLAGS="${CFLAGS}"

# Use shared OpenSSL (static libs not available in this environment)
sed -i 's/set(OPENSSL_USE_STATIC_LIBS TRUE)/set(OPENSSL_USE_STATIC_LIBS FALSE)/' cmake/FDBComponents.cmake

# Disable flowbench (not needed for production builds)
sed -i '/add_subdirectory(flowbench/s/^/#/' CMakeLists.txt

# Disable the binding tester. bindings/CMakeLists.txt guards it with only
# `if(NOT WIN32 AND NOT OPEN_FOR_IDE)`, so on Linux it runs unconditionally --
# it ignores every WITH_*_BINDING flag AND BUILD_TESTING=OFF. Its
# prepare_binding_test_files step then fails:
#   FAILED: bindingtester.touch
#   Error copying directory from "/build/bindings" to ".../bindingtester/tests":
#     No such file or directory
# (This is also why the Python stub files below were needed -- same target.)
sed -i '/package_bindingtester/s/^/#/' bindings/CMakeLists.txt

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
  -DUSE_JEMALLOC=OFF \
  -DOPENSSL_ROOT_DIR="$OSSL3" \
  -DOPENSSL_INCLUDE_DIR="$OSSL3/include" \
  -DOPENSSL_SSL_LIBRARY="$OSSL3/lib/libssl.so" \
  -DOPENSSL_CRYPTO_LIBRARY="$OSSL3/lib/libcrypto.so"

# Create stub Python binding files so copy_binding_output_files target succeeds
# (Python bindings are disabled but the binding tester still tries to copy them)
mkdir -p build/bindings/python/fdb
touch build/bindings/python/fdb/fdboptions.py
touch build/bindings/python/fdb/apiversion.py

JOBS=$(( $(nproc) / 4 ))
[ "$JOBS" -lt 1 ] && JOBS=1

ninja -C build -j"$JOBS"
DESTDIR="$OUTPUT_DIR" ninja -C build -j"$JOBS" install

# Move sbin binaries (fdbserver) to bin
mv "$OUTPUT_DIR/usr/sbin/"* "$OUTPUT_DIR/usr/bin/" 2>/dev/null || true
rmdir "$OUTPUT_DIR/usr/sbin" 2>/dev/null || true

# Move fdbmonitor to bin (separate binary)
mv "$OUTPUT_DIR/usr/lib/foundationdb/fdbmonitor" "$OUTPUT_DIR/usr/bin/" 2>/dev/null || true

# Replace duplicate copies of fdbbackup with symlinks (argv[0]-dispatched)
rm -f "$OUTPUT_DIR/usr/lib/foundationdb/backup_agent/backup_agent" 2>/dev/null || true
for name in fdbrestore fdbdr dr_agent backup_agent; do
  rm -f "$OUTPUT_DIR/usr/bin/$name" 2>/dev/null || true
  ln -s fdbbackup "$OUTPUT_DIR/usr/bin/$name"
done
rm -rf "$OUTPUT_DIR/usr/lib/foundationdb" 2>/dev/null || true

# Fail closed: the server and the client library must have linked OpenSSL 3 (libssl.so.3),
# never 4.x (libssl.so.4).
test -e "$OUTPUT_DIR/usr/bin/fdbserver"
for f in "$OUTPUT_DIR/usr/bin/fdbserver" "$OUTPUT_DIR"/usr/lib/libfdb_c*.so*; do
  [ -L "$f" ] && continue
  readelf -d "$f" | grep -q 'NEEDED.*\[libssl\.so\.3\]' || { echo "ERROR: $f does not link libssl.so.3" >&2; exit 1; }
  ! readelf -d "$f" | grep -q 'NEEDED.*libssl\.so\.4' || { echo "ERROR: $f links libssl.so.4" >&2; exit 1; }
done
