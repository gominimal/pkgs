#!/bin/sh
set -e

mkdir -p bootstrap
tar -xof "go${MINIMAL_ARG_VERSION}.linux-amd64.tar.gz" -C bootstrap
export GOROOT_BOOTSTRAP="$(pwd)/bootstrap/go"

tar -xof "go${MINIMAL_ARG_VERSION}.src.tar.gz"
cd go/src
GOROOT=/usr/go ./make.bash # TODO: do ./all.bash once we have /etc setup correctly so those tests will pass

mkdir -p $OUTPUT_DIR/usr/{bin,go}
cp -r ../* $OUTPUT_DIR/usr/go/

for bin in ../bin/*; do
    ln -sv "../go/bin/$(basename "$bin")" "$OUTPUT_DIR/usr/bin/$(basename "$bin")";
done
