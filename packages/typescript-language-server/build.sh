#!/bin/sh
set -ex

# Pin typescript. Installing it unpinned pulled TypeScript 7.0.2 (the native
# rewrite), which DROPPED the `tsserver` bin entry (its bin is now just `tsc`),
# so the `usr/bin/tsserver` output glob matched nothing and the build failed.
# 5.9.3 is the latest 5.x, still ships tsserver, and is what
# typescript-language-server 4.3.3 targets. Pinning also makes this
# internet-fetching build deterministic instead of tracking npm's `latest`.
#
# Install into a package-PRIVATE prefix (NOT the shared usr/lib/node_modules, which
# node/node-lts own); expose thin symlinks on PATH. Both npm packages land in the
# one prefix. Only typescript-language-server and tsserver go on PATH: the
# bundled 5.9.3 tsc would collide with the typescript package's /usr/bin/tsc
# (a file conflict in any box with both), and the server does not need it there.
# The inner `#!/usr/bin/env node` shebang is served by coreutils+node.
npm install -g --prefix="$OUTPUT_DIR/usr/libexec/typescript-language-server" \
  typescript-language-server@$MINIMAL_ARG_VERSION \
  typescript@5.9.3

mkdir -p "$OUTPUT_DIR/usr/bin"
for _tool in typescript-language-server tsserver; do
  _bin="$OUTPUT_DIR/usr/libexec/typescript-language-server/bin/$_tool"
  [ -e "$_bin" ] || { echo "missing $_bin" >&2; exit 1; }
  ln -s "../libexec/typescript-language-server/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
done
