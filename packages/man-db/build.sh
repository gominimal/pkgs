#!/bin/sh
set -ex

tar xf man-db-2.13.1.tar.gz
cd man-db-2.13.1

git init # bootstrap complains w/o parent git repo for gnulib checkout

# fails with
#  useradd: Permission denied.
#  useradd: cannot lock /etc/passwd; try again later.
#useradd -U man  # for final install with user and group for "man"

./bootstrap # super slow due to git checkout of gnulib

./configure  --prefix=/usr     \
             --disable-setuid # gets around lack of useradd, but man page cache not updated by users using man

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
