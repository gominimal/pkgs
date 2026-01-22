#!/bin/sh
set -e

sed -i '/install -m.*STA/d' libcap/Makefile

# TODO: Remove once /usr/bin/bash shows up in the bash build-spec output
sed -i 's#/bin/bash#/usr/bin/bash#g' progs/mkcapshdoc.sh

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

make prefix=/usr lib=lib

make prefix=/usr lib=lib DESTDIR="$OUTPUT_DIR" install
