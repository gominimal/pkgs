#!/bin/sh
set -e

tar -xof iana-etc-20261106.tar.gz
cd iana-etc-20261106

mkdir -p "$OUTPUT_DIR/etc"
cp services protocols "$OUTPUT_DIR/etc/"
