#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export CC=gcc
export CCC=g++
export CXX=g++

cd nss
make -j$(nproc) \
  BUILD_OPT=1 \
  USE_64=1 \
  NSS_USE_SYSTEM_SQLITE=1 \
  NSS_DISABLE_GTESTS=1 \
  NSPR_INCLUDE_DIR=/usr/include/nspr \
  NSPR_LIB_DIR=/usr/lib \
  USE_SYSTEM_ZLIB=1 \
  ZLIB_LIBS=-lz

cd ..

# Manual install (NSS doesn't have make install)
install -d $OUTPUT_DIR/usr/{lib,bin,include/nss,lib/pkgconfig}

cd dist
install -m 755 Linux*/lib/*.so $OUTPUT_DIR/usr/lib/
install -m 644 Linux*/lib/*.chk $OUTPUT_DIR/usr/lib/ 2>/dev/null || true
install -m 644 public/nss/*.h $OUTPUT_DIR/usr/include/nss/
install -m 755 Linux*/bin/{certutil,pk12util} $OUTPUT_DIR/usr/bin/

# Create nss.pc
NSS_VMAJOR=$(grep '#define.*NSS_VMAJOR' public/nss/nss.h | awk '{print $3}')
NSS_VMINOR=$(grep '#define.*NSS_VMINOR' public/nss/nss.h | awk '{print $3}')
NSS_VPATCH=$(grep '#define.*NSS_VPATCH' public/nss/nss.h | awk '{print $3}')
cat > $OUTPUT_DIR/usr/lib/pkgconfig/nss.pc << EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/nss

Name: NSS
Description: Network Security Services
Version: ${NSS_VMAJOR}.${NSS_VMINOR}.${NSS_VPATCH}
Requires: nspr
Libs: -L\${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
Cflags: -I\${includedir}
EOF
