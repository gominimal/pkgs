#!/bin/sh
set -ex

# Deterministic constant bytes: identical sha256 across a/b/re-runs.
# No $(date), no randomness, no host-path leak (determinism is the point).
mkdir -p "$OUTPUT_DIR/usr/share/bedrock"
printf 'bedrock-rung1\n' > "$OUTPUT_DIR/usr/share/bedrock/rung1"
