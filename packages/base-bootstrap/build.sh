#!/bin/sh
set -ex

mkdir -p $OUTPUT_DIR/etc
cat > $OUTPUT_DIR/etc/hosts << "EOF"
127.0.0.1   localhost
::1         localhost
EOF
