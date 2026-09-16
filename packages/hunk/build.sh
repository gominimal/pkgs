#!/bin/bash
set -euo pipefail

mkdir -p .bun-tmp .bun-install
export BUN_TMPDIR="$PWD/.bun-tmp"
export BUN_INSTALL="$PWD/.bun-install"

bun install --frozen-lockfile --ignore-scripts

# 0.22.0 restructured the repo into a bun workspace monorepo: the app moved
# from ./src to packages/hunk/src, and the root package.json became
# @hunk/workspace with `workspaces: ["packages/*"]`. Upstream's own scripts
# agree — "start": "bun run packages/hunk/src/main.tsx".
bun build --compile ./packages/hunk/src/main.tsx --outfile hunk

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 hunk "$OUTPUT_DIR/usr/bin/hunk"
ln -s hunk "$OUTPUT_DIR/usr/bin/hunkdiff"
