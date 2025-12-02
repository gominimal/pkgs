#!/bin/sh
set -e

DYNAMIC_ARCH=1 make
DESTDIR="$OUTPUT_DIR" PREFIX=/usr make install
