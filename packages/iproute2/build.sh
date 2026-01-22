#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

make NETNS_RUN_DIR=/run/netns -j$(nproc)
make SBINDIR=/usr/sbin DESTDIR=$OUTPUT_DIR install
