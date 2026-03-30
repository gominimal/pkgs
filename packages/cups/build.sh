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

./configure --prefix=/usr \
            --disable-static \
            --with-tls=openssl \
            --without-systemd \
            --disable-libusb \
            --disable-dbus \
            --disable-pam

# Only build the client library (Chromium only needs libcups)
make -C cups -j$(nproc)

# Install library and headers manually
install -d $OUTPUT_DIR/usr/lib $OUTPUT_DIR/usr/include/cups $OUTPUT_DIR/usr/lib/pkgconfig
cp cups/libcups*.so* $OUTPUT_DIR/usr/lib/ 2>/dev/null || true
cp cups/libcups*.a $OUTPUT_DIR/usr/lib/ 2>/dev/null || true
cp cups/*.h $OUTPUT_DIR/usr/include/cups/
cp cups/cups.pc $OUTPUT_DIR/usr/lib/pkgconfig/ 2>/dev/null || true

# If .pc wasn't generated in cups/, check top-level
if [ ! -f $OUTPUT_DIR/usr/lib/pkgconfig/cups.pc ]; then
  # Generate a basic cups.pc
  cat > $OUTPUT_DIR/usr/lib/pkgconfig/cups.pc << EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: cups
Description: CUPS Client Library
Version: 2.4.13
Libs: -L\${libdir} -lcups
Cflags: -I\${includedir}
EOF
fi
