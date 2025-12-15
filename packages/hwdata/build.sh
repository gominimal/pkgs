#!/bin/sh
set -e

./configure --prefix=/usr --disable-blacklist

make DESTDIR=$OUTPUT_DIR        \
     install
