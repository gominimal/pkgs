#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                   \
            --infodir=/usr/share/info       \
            --mandir=/usr/share/man         \
            --disable-pam                   \
            --enable-socket-dir=/run/screen \
            --with-pty-group=5              \
            --with-system_screenrc=/etc/screenrc

sed -i -e "s%/usr/local/etc/screenrc%/etc/screenrc%" {etc,doc}/*
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
mkdir -pv $OUTPUT_DIR/etc
install -m 644 etc/etcscreenrc $OUTPUT_DIR/etc/screenrc
