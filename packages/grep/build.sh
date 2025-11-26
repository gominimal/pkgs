#!/bin/sh
set -e

sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix="/usr"

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install-strip
