#!/bin/sh
set -ex

# Install from the sha256-pinned registry tarball fetched as a Source (not from
# the live `cf@<version>` tag), so the exact audited artifact is what ships.
# Install into a package-PRIVATE prefix, NOT the shared usr/lib/node_modules
# the node runtime owns (#370, #751): anything a package drops there is merged
# first-writer-wins with every other closure member's tree.
npm install -g --prefix="$OUTPUT_DIR/usr/libexec/cf" "cf-${MINIMAL_ARG_VERSION}.tgz"

# Expose the declared bins as relative PATH symlinks into the private prefix.
# `test -e` follows the chain, so a renamed upstream bin fails the build here
# rather than shipping a dangling link.
mkdir -p "$OUTPUT_DIR/usr/bin"
for _tool in cf; do
  ln -s "../libexec/cf/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
  test -e "$OUTPUT_DIR/usr/bin/$_tool" || { echo "cf: npm did not install bin $_tool" >&2; exit 1; }
done
