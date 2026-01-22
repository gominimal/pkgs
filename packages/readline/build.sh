#!/bin/sh
set -e

tar xfo readline-8.3.tar.gz
cd readline-8.3

sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr   \
           --disable-static \
           --with-curses    \
           --docdir="/usr/share/doc/readline-8.3"


make -j$(nproc) SHLIB_LIBS="-lncursesw"
make DESTDIR=$OUTPUT_DIR install
