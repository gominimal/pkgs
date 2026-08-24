#!/bin/sh
set -ex

# Install the sha256-pinned registry tarball fetched as a Source (not the live
# name@version tag), so the exact audited artifact is what ships. The tarball's
# bundled npm-shrinkwrap.json locks the transitive dependency tree, keeping the
# build reproducible. Install into a package-PRIVATE prefix (NOT the shared
# usr/lib/node_modules, which the node runtime owns) so the tool can't collide
# with it; expose thin symlinks on PATH. The inner `#!/usr/bin/env node`
# shebang is served by coreutils(env)+node, so no shell is needed.
npm install -g --prefix="$OUTPUT_DIR/usr/libexec/pi" \
  "pi-coding-agent-$MINIMAL_ARG_VERSION.tgz"

mkdir -p "$OUTPUT_DIR/usr/bin"
for _bin in "$OUTPUT_DIR/usr/libexec/pi/bin/"*; do
  [ -e "$_bin" ] || continue
  _tool=${_bin##*/}
  ln -s "../libexec/pi/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
done
