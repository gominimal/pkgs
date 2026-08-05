#!/bin/sh
# Imported from npm `vlt` (1.0.1, node) by pkgmgr import npm.
set -eu

# Reproducible install: `npm ci` from the committed package-lock.json pins
# the WHOLE transitive tree by version + integrity (a bare `npm install`
# re-resolves it at build time). Install into a package-PRIVATE libexec
# prefix (NOT the shared usr/lib/node_modules the node runtime owns) and
# expose bins as PATH symlinks; the inner `#!/usr/bin/env node` shebang is
# served by coreutils(env)+node, so no shell wrapper is needed.
# Guard: the committed lock must pin the build.ncl version (the updater
# regenerates it on a bump; this catches a hand-edited version drift).
grep -qF "\"$MINIMAL_ARG_VERSION\"" package.json ||
  { echo "package.json does not pin $MINIMAL_ARG_VERSION — regenerate the lockfile" >&2; exit 1; }
prefix="$OUTPUT_DIR/usr/libexec/vlt"
mkdir -p "$prefix"
cp package.json package-lock.json "$prefix/"
cd "$prefix"
npm ci --omit=dev

mkdir -p "$OUTPUT_DIR/usr/bin"
for _bin in node_modules/.bin/*; do
  [ -e "$_bin" ] || continue
  _tool=${_bin##*/}
  ln -s "../libexec/vlt/node_modules/.bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
done
