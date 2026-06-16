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

cmake -B build
cmake --build build --config Release -j $(nproc)

mkdir -pv $OUTPUT_DIR/usr/{bin,lib}

# Copy ALL shared objects preserving versioned sonames + symlinks. The old
# `install build/bin/*.so` matched only the unversioned dev symlinks (libfoo.so)
# and `install` dereferenced them into plain libfoo.so files — but the binaries
# link against the SONAMEs (libllama-common.so.0, libggml.so.0, libmtmd.so.0, …),
# so the .so.0 reals (and libmtmd entirely) went missing → runtime "cannot open
# shared object libllama-common.so.0". `cp -a *.so*` keeps the .so.0 reals + the
# .so->.so.0 symlinks; /usr/lib is on the default ld.so path, so no rpath needed.
cp -av build/bin/*.so* $OUTPUT_DIR/usr/lib/
install -vm755 build/bin/llama-{cli,server} $OUTPUT_DIR/usr/bin/
