#!/bin/sh
set -ex

# Install the sha256-pinned source release with upstream's own package-lock.json
# (npm ci: exact versions, integrity-checked), production deps only. All 9 are
# pure JavaScript with no install scripts, so --ignore-scripts loses nothing.
# This is upstream's documented npm install, which runs the CLI on node-lts
# instead of the yao-pkg binary's embedded Node 20 (see build.ncl).
npm ci --omit=dev --ignore-scripts --no-audit --no-fund

# Install into a package-PRIVATE prefix, NOT the shared usr/lib/node_modules the
# node runtime owns (#370, #751).
DEST="$OUTPUT_DIR/usr/libexec/dotenvx"
install -d "$DEST"
cp -R package.json LICENSE src node_modules "$DEST/"

# Expose the CLI as a relative PATH symlink into the private prefix. `test -e`
# follows the chain, so a moved upstream entry point fails the build here
# rather than shipping a dangling link.
install -d "$OUTPUT_DIR/usr/bin"
ln -s ../libexec/dotenvx/src/cli/dotenvx.js "$OUTPUT_DIR/usr/bin/dotenvx"
test -e "$OUTPUT_DIR/usr/bin/dotenvx" || { echo "dotenvx: src/cli/dotenvx.js missing" >&2; exit 1; }
