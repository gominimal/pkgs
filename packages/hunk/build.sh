#!/bin/bash
set -euo pipefail

mkdir -p .bun-tmp .bun-install
export BUN_TMPDIR="$PWD/.bun-tmp"
export BUN_INSTALL="$PWD/.bun-install"

# #47: extract the pre-materialized node_modules (staged by
# `orch stage bun hunk --node-modules`) so the install below is a no-op
# verify with ZERO network. A cold `bun install` always contacts the
# registry for metadata even with a populated cache -> blackholed connect()
# -> hang, so the materialized tree is the only offline-safe path.
NM_TAR="$(ls /build/hunk-allnm-*.tar.gz 2>/dev/null | head -1)"
[ -n "$NM_TAR" ] || { echo "FATAL #47: hunk node_modules tarball missing in /build" >&2; exit 1; }
tar --no-same-owner -xzf "$NM_TAR" -C /build
echo "[hunk build.sh] pre-materialized node_modules ($(ls node_modules 2>/dev/null | wc -l) entries)"

bun install --frozen-lockfile --ignore-scripts

bun build --compile ./src/main.tsx --outfile hunk

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 hunk "$OUTPUT_DIR/usr/bin/hunk"
ln -s hunk "$OUTPUT_DIR/usr/bin/hunkdiff"
