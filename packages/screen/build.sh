#!/bin/sh
set -e

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
