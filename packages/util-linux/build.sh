#!/bin/sh
set -e

tar xfo "util-linux-${MINIMAL_ARG_VERSION}.tar.xz"
cd "util-linux-${MINIMAL_ARG_VERSION}"

./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            --without-systemd     \
            --without-systemdsystemunitdir        \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux    \
            --disable-makeinstall-chown \
            --disable-use-tty-group     \

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
