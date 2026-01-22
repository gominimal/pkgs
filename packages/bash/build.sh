#!/bin/sh
set -e

cd "bash-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --without-bash-malloc \
            --docdir=/usr/share/doc/bash-5.3 \
            --with-installed-readline

make -j$(nproc)
# TODO make tests
make DESTDIR=$OUTPUT_DIR install-strip

# Create sh symlink in /usr/bin
ln -sf bash $OUTPUT_DIR/usr/bin/sh
