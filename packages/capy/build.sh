#!/bin/sh
set -ex

# The @capysc/cli source tarball is declared as a Source in build.ncl
# (extract = true, strip_prefix), so its contents are already unpacked into the
# working directory. Build it from source rather than installing the prebuilt
# npm artifact.

npm install                  # no committed lockfile upstream -> install, not ci
npm run build                # tsc -> dist/
npm pkg delete bin.capy-dev  # match the published artifact (upstream prepublishOnly)

# Pack the built package, then install the tarball into the output prefix.
# Packing first copies real files in; a bare `npm install -g .` would instead
# symlink back to the source dir, which escapes $OUTPUT_DIR.
npm pack
# Install into a package-PRIVATE prefix, NOT the shared usr/lib/node_modules
# the node runtime owns (#370, #751): anything a package drops there is merged
# first-writer-wins with every other closure member's tree.
npm install -g --prefix="$OUTPUT_DIR/usr/libexec/capy" ./*.tgz

# Expose the declared bins as relative PATH symlinks into the private prefix.
# `test -e` follows the chain, so a renamed upstream bin fails the build here
# rather than shipping a dangling link.
mkdir -p "$OUTPUT_DIR/usr/bin"
for _tool in capy; do
  ln -s "../libexec/capy/bin/$_tool" "$OUTPUT_DIR/usr/bin/$_tool"
  test -e "$OUTPUT_DIR/usr/bin/$_tool" || { echo "capy: npm did not install bin $_tool" >&2; exit 1; }
done
