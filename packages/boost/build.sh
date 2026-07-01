#!/bin/sh
set -e

tar -xof boost-1.91.0-1-b2-nodocs.tar.xz
cd boost-1.91.0-1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./bootstrap.sh --prefix=/usr --with-python=python3
./b2 stage -j$(nproc) threading=multi link=shared

# Deliberately do NOT run Boost.Build's engine self-test suite
# (tools/build/test/test_all.py) here: it validates the b2 build *tool*, not
# boost, so it's unnecessary for packaging — and it spawns a
# multiprocessing.Pool(cpu_count()) that deadlocks in the build sandbox (49 idle
# workers, empty /dev/shm), which wedged the whole fleet for hours once the
# res-servers went to 48 cores. Don't re-add it.

./b2 --prefix=$OUTPUT_DIR/usr install threading=multi link=shared
