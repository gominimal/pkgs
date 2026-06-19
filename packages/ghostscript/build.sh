#!/bin/sh
set -e

# Remove source trees for libraries which are bundled but we build separately
rm -rf freetype lcms2mt jpeg libpng openjpeg

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Reproducibility: mkromfs/pack_ps read SOURCE_DATE_EPOCH but then do
# `if (!buildtime) buildtime = time(NULL)`, which treats the sandbox's
# SOURCE_DATE_EPOCH=0 (epoch 0 is falsy) as "unset" and falls back to wall-clock
# time -> non-deterministic gs_romfs_buildtime baked into the gs binary. Only
# fall back to time() when SOURCE_DATE_EPOCH is genuinely unset.
sed -i 's/if (!buildtime)/if (!env_source_date_epoch)/' base/mkromfs.c base/pack_ps.c

./configure --prefix=/usr \
            --disable-static \
            --with-system-libtiff \
            --disable-compiler-inits \
            CFLAGS="${CFLAGS:--g -O3} -fPIC"

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
