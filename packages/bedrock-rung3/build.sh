#!/bin/sh
set -ex

# rung3 consumes rung2's output (Build build_dep -> /usr/share/bedrock/rung2),
# giving the depth-2 chain rung3 -> rung2 -> rung1 the Phase-6b descent tamper
# needs. Deterministic: constant predecessor bytes + constant marker.
mkdir -p "$OUTPUT_DIR/usr/share/bedrock"
cat /usr/share/bedrock/rung2 > "$OUTPUT_DIR/usr/share/bedrock/rung3"
printf 'bedrock-rung3\n' >> "$OUTPUT_DIR/usr/share/bedrock/rung3"
