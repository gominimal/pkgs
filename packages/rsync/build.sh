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

# rsync 3.5.1 aborts configure when an optional library it probes for is
# absent unless the feature is disabled explicitly; IDN needs libidn2, which
# is not in our closure and adds nothing we use (internationalised hostnames).
./configure --disable-idn

make -j$(nproc) DESTDIR=$OUTPUT_DIR prefix=/usr install
