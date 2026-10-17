#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# GGML_NATIVE defaults ON and adds -march=native, so the generated code follows the CPU
# of whichever res-server rung the build landed on (2026-10 prod-pair diff: 31% of
# libllama-server-impl.so regenerated between two builds, identical symbol set). The
# explicit $MARCH in CFLAGS is the target; let it be the only one.
cmake -B build -DGGML_NATIVE=OFF
cmake --build build --config Release -j $(nproc)

mkdir -pv $OUTPUT_DIR/usr/{bin,lib}

install -vm755 build/bin/*.so $OUTPUT_DIR/usr/lib/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
