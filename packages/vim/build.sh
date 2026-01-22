#!/bin/sh
set -e

tar xfo vim-9.1.1629.tar.gz
cd vim-9.1.1629

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr        \
            --with-features=huge \
            --enable-gui=no      \
            --without-x          \
            --with-tlib=ncursesw

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
