#!/bin/sh
set -e

./configure --prefix=/usr                   \
            --with-gitconfig=/etc/gitconfig \
            --with-python=python3           \
            --with-libpcre2

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR NO_INSTALL_HARDLINKS=1 install

find -L "${OUTPUT_DIR}/usr/bin" -xtype f -executable | xargs strip --strip-debug || true
find -L "${OUTPUT_DIR}/usr/libexec/git-core" -xtype f -executable | xargs strip --strip-debug || true
