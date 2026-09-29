#!/bin/sh
set -ex

# Install into a package-PRIVATE prefix, NOT the shared usr/lib/node_modules
# the node runtime owns (#370, #751): anything a package drops there is merged
# first-writer-wins with every other closure member's tree.
npm install -g --prefix="$OUTPUT_DIR/usr/libexec/wrangler" "wrangler@$MINIMAL_ARG_VERSION"

# Expose the declared bins as relative PATH symlinks into the private prefix.
# `test -e` follows the chain, so a renamed upstream bin fails the build here
# rather than shipping a dangling link.
mkdir -p "$OUTPUT_DIR/usr/bin"
for _tool in wrangler wrangler2 cf-wrangler; do
  ln -s "../libexec/wrangler/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
  test -e "$OUTPUT_DIR/usr/bin/$_tool" || { echo "wrangler: npm did not install bin $_tool" >&2; exit 1; }
done
