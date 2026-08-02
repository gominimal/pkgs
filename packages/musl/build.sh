#!/bin/bash
set -euo pipefail


export CFLAGS="-O3 -pipe -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

./configure --prefix=/usr/local/musl --syslibdir=/usr/local/musl/lib
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

# Minimal's sandbox requires symlinks to be relative to the output directory
# musl creates an absolute symlink: ld-musl-<arch>.so.1 -> /usr/local/musl/lib/libc.so
cd $OUTPUT_DIR/usr/local/musl/lib
for f in ld-musl-*.so.1; do
    if [ -L "$f" ]; then
        ln -sf libc.so "$f"
    fi
done

# Expose musl-gcc in the standard PATH so it's easy to use
mkdir -p $OUTPUT_DIR/usr/bin
ln -sf ../local/musl/bin/musl-gcc $OUTPUT_DIR/usr/bin/musl-gcc
