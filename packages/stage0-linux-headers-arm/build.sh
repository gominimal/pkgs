#!/bin/sh
set -ex

tar -xof linux-6.12.43.tar.xz
cd linux-6.12.43

# `make headers` first builds scripts/unifdef with the HOST compiler. unifdef.c includes <errno.h>,
# and glibc's /usr/include/bits/errno.h line 26 does `#include <linux/errno.h>` — the very headers
# this recipe exists to produce. Measured failure without the flag below:
#
#   /usr/include/bits/errno.h:26:11: fatal error: linux/errno.h: No such file or directory
#   make[2]: *** [scripts/Makefile.host:116: scripts/unifdef] Error 1
#
# The amd64 rung dodges this by building against a musl sysroot, whose errno.h does not chain into
# linux/. arm does not have that sysroot available here, and does not need it: THE KERNEL SOURCE
# ALREADY CONTAINS THESE HEADERS at include/uapi. Pointing HOSTCFLAGS at the tree's own uapi dir
# resolves linux/errno.h from the source we are about to install, which is the same content by
# construction — not a substitute from somewhere else.
make headers HOSTCFLAGS="-I$PWD/include/uapi"

mkdir -p $OUTPUT_DIR/usr
cp -rv usr/include $OUTPUT_DIR/usr/
