#!/bin/sh
set -ex

mkdir -p $OUTPUT_DIR/etc
cat > $OUTPUT_DIR/etc/resolv.conf << "EOF"
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
