#!/bin/sh
set -e

sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg

sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
    -i include/freetype/config/ftoption.h

./configure --prefix=/usr --enable-freetype-config --disable-static
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
