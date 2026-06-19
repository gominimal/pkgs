#!/bin/sh
set -ex

# rung4 is the FRESH (never-cached) consumer for the live tamper test: it
# build-depends on rung3, giving the depth-3 chain rung4 -> rung3 -> rung2 ->
# rung1. Because it's never been built, a `--chain-enforce` build genuinely
# re-walks the chain (rung1/2/3 are cached, so re-enqueuing them just HITs and
# skips). Deterministic: constant predecessor bytes + constant marker.
mkdir -p "$OUTPUT_DIR/usr/share/bedrock"
cat /usr/share/bedrock/rung3 > "$OUTPUT_DIR/usr/share/bedrock/rung4"
printf 'bedrock-rung4\n' >> "$OUTPUT_DIR/usr/share/bedrock/rung4"
