#!/bin/sh
set -ex

# rung2 genuinely consumes rung1's output: rung1 is a Build build_dep, so its
# OutputData (usr/share/bedrock/rung1) is hardlinked into this build's rootfs
# at /usr/share/bedrock/rung1. Catting it makes rung2's bytes depend on rung1
# being present -> a real predecessor edge for the B0b chain walk.
# Deterministic: rung1's bytes are constant, and the appended marker is constant.
mkdir -p "$OUTPUT_DIR/usr/share/bedrock"
cat /usr/share/bedrock/rung1 > "$OUTPUT_DIR/usr/share/bedrock/rung2"
printf 'bedrock-rung2\n' >> "$OUTPUT_DIR/usr/share/bedrock/rung2"
