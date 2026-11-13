#!/bin/sh
set -ex

tar -xof linux-6.12.115.tar.xz
cd linux-6.12.115

make headers
mkdir -p $OUTPUT_DIR/usr
cp -rv usr/include $OUTPUT_DIR/usr/
