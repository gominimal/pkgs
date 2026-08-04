#!/bin/bash
set -euo pipefail


export CC=gcc
export CFLAGS="-O3 -pipe -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# Patch configure.sh to remove the broken expanding here-doc block
sed -i '/^cat >>\$CONFIG_STATUS <<_ACEOF || ac_write_fail=1$/{
  N
  /\n_ACEOF$/d
}' configure.sh

./configure

make -j$(nproc) DESTDIR=$OUTPUT_DIR prefix=/usr install
