#!/bin/sh
set -e

make NETNS_RUN_DIR=/run/netns -j$(nproc)
make SBINDIR=/usr/sbin DESTDIR=$OUTPUT_DIR install
