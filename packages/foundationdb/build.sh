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

# OpenSSL 4. FDB 7.3 breaks against it in four places (const X509 accessors, opaque
# ASN1_STRING); upstream has no fix (apple/foundationdb#14348 pins 3.5 instead):
#   1-3. flow/MkCert.cpp and flow/TLSConfig.actor.cpp: foundationdb-7.3.81-openssl4.patch
#        (MkCert builds the subject X509_NAME separately; TLSConfig gains `const` only).
#   4.   The bundled Boost 1.78 (FDB 7.3 needs <= 1.86 for asio::io_service) includes
#        asio's deprecated rfc2818_verification.ipp from <boost/asio/ssl.hpp>; it reads
#        ASN1_STRING members directly. FDB never uses that class, so pre-define its
#        include guard to skip the header. Boost >= 1.87 removed the file.
# Drop the patch and the define when upstream supports OpenSSL 4.
# Both hashes are checked, so a different upstream file fails here instead of being
# patched wrongly, and a partial apply cannot pass.
export CXXFLAGS="$CXXFLAGS -DBOOST_ASIO_SSL_RFC2818_VERIFICATION_HPP"
echo "62cdc1608984fcba0cadfe307359248ca0f7de0d41e9b953b2efd435bca12b0f  flow/MkCert.cpp" | sha256sum -c -
echo "6299add9da324462fac0bbf02f1910b9f3e6fb16225156d80a101244c675dbac  flow/TLSConfig.actor.cpp" | sha256sum -c -
patch -Np1 -F0 -i ./foundationdb-7.3.81-openssl4.patch
echo "4bd67b138411a0b11d95fa4cf1f903d51d0e938fd2656a3a91d0f4d7c85c20e5  flow/MkCert.cpp" | sha256sum -c -
echo "af4ff3d4a18c4392b540ca56229e73779b9dfcc62c4ad0057726afd65e91ac96  flow/TLSConfig.actor.cpp" | sha256sum -c -

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

# C++20 forbids naming a constructor with a template-id (`Promise<T>(...)`
# inside `class Promise`); gcc 16 rejects it (-Wtemplate-id-cdtor, found by
# the gcc 16.2 world-build canary, gominimal/pkgmgr-rs#1182). Upstream still
# has all four on main. The plain name means the same thing in every standard,
# so this is a no-op for gcc 15. sed -i is silent on a miss, so check after.
sed -i 's/explicit Promise<T>(SAV<T>\* ptr)/explicit Promise(SAV<T>* ptr)/' flow/include/flow/flow.h
sed -i 's/explicit ReplyPromise<T>(SAV<T>\* ptr)/explicit ReplyPromise(SAV<T>* ptr)/' fdbrpc/include/fdbrpc/fdbrpc.h
sed -i 's/explicit IteratorImpl<isConst>(/explicit IteratorImpl(/' fdbrpc/include/fdbrpc/RangeMap.h flow/include/flow/IndexedSet.h
if grep -nE 'explicit (Promise<T>|ReplyPromise<T>|IteratorImpl<isConst>)\(' \
  flow/include/flow/flow.h fdbrpc/include/fdbrpc/fdbrpc.h \
  fdbrpc/include/fdbrpc/RangeMap.h flow/include/flow/IndexedSet.h; then
  echo "foundationdb: template-id constructor fix did not apply" >&2
  exit 1
fi

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

# Fail closed: built against OpenSSL 4 (libssl.so.4), never the 3.x compat tree.
test -e "$OUTPUT_DIR/usr/bin/fdbserver"
# fdbserver (which does TLS) must NEED libssl.so.4 as the positive control, and
# nothing we ship may NEED the 3.x libraries. Not every library links OpenSSL:
# libfdb_c_shim.so dlopen()s libfdb_c at run time and links no SSL itself, so
# "links .so.4" is required of fdbserver only.
readelf -d "$OUTPUT_DIR/usr/bin/fdbserver" | grep -q 'NEEDED.*\[libssl\.so\.4\]' || {
  echo "ERROR: fdbserver does not link libssl.so.4 (OpenSSL 4)" >&2; exit 1; }
for f in "$OUTPUT_DIR"/usr/bin/* "$OUTPUT_DIR"/usr/lib/*.so*; do
  [ -L "$f" ] && continue
  [ -f "$f" ] || continue
  readelf -h "$f" >/dev/null 2>&1 || continue
  ! readelf -d "$f" | grep -qE 'NEEDED.*lib(ssl|crypto)\.so\.3' || {
    echo "ERROR: $f links OpenSSL 3 (libssl/libcrypto .so.3)" >&2; exit 1; }
done
