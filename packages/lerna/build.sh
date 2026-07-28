#!/bin/sh
# Imported from Wolfi `lerna` (9.0.7, node) by pkgmgr import-wolfi.
set -eu

# Install into a package-PRIVATE prefix (NOT the shared usr/lib/node_modules, which
# the node/node-lts runtime owns) so the tool can't collide with it; expose thin
# symlinks on PATH. The inner `#!/usr/bin/env node` shebang is served by
# coreutils(env)+node, so no shell is needed. (twitchyliquid64 review on #370.)
npm install -g --prefix="$OUTPUT_DIR/usr/libexec/lerna" "lerna@$MINIMAL_ARG_VERSION"

mkdir -p "$OUTPUT_DIR/usr/bin"
for _bin in "$OUTPUT_DIR/usr/libexec/lerna/bin/"*; do
  [ -e "$_bin" ] || continue
  _tool=${_bin##*/}
  ln -s "../libexec/lerna/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
done
