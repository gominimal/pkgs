#!/bin/sh
set -e

tar -xof iana-etc-20261015.tar.gz
cd iana-etc-20261015

mkdir -p "$OUTPUT_DIR/etc"
cp services protocols "$OUTPUT_DIR/etc/"
