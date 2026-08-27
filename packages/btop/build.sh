#!/bin/sh
set -e
cd btop-1.4.7

# C++23 -> C++20 bridge: btop 1.4.7 uses std::ranges::to (needs gcc >= 14),
# but during world rebuilds the arm64 bootstrap seed (g++ 12.4.0) compiles
# this package. REMOVE this patch when the arm64 replace_on_cycle seed
# reaches gcc >= 14 — tracked in pkgs#651.
patch -p1 < ../gcc12-seed.patch

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Disable GPU paths at compile time
make -j"$(nproc)" GPU_SUPPORT=false
make DESTDIR="${OUTPUT_DIR}" PREFIX="/usr" install
