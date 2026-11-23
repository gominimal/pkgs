#!/bin/sh
set -e
mkdir -p "$OUTPUT_DIR/usr/share/egress-canary"
python3 probe.py | tee "$OUTPUT_DIR/usr/share/egress-canary/result"
