#!/bin/bash
set -euo pipefail

# Sandbox doesn't have a cc symlink; point to gcc for native addon compilation
export CC=gcc
export CXX=g++

# Install all dependencies using the repo's pnpm-lock.yaml for reproducibility.
# The lockfile pins exact versions of every transitive dependency used during the build.
pnpm install --frozen-lockfile

# Build next and all its workspace dependencies (e.g. @next/env)
pnpm exec turbo run build --filter=next...

# Pack the built package into a tarball (resolves workspace: protocols to real versions)
cd packages/next
pnpm pack --pack-destination /tmp

# Install the package globally from the tarball
npm install -g --prefix=$OUTPUT_DIR/usr "/tmp/next-$MINIMAL_ARG_VERSION.tgz"

NEXT_DIR="$OUTPUT_DIR/usr/lib/node_modules/next"

# Build sharp from source against our system libvips
SHARP_STAGING=$(mktemp -d)
cd "$SHARP_STAGING"
echo '{"private":true}' > package.json

# Install sharp without scripts (skip prebuilt download), then compile native addon.
# Use npm here (not pnpm) so node_modules is flat, avoiding pnpm symlinks in the output.
npm install --ignore-scripts sharp node-addon-api node-gyp
export PATH="$SHARP_STAGING/node_modules/.bin:$PATH"
cd node_modules/sharp
node install/build.js

# Clean up native build artifacts, keeping only the final .node addon
find src/build -name '*.o' -delete
rm -rf src/build/Release/obj.target
rm -rf src/build/Release/.deps

# Copy the source-built sharp into next's node_modules
cd "$SHARP_STAGING"
cp -r node_modules/sharp "$NEXT_DIR/node_modules/sharp"

# Copy sharp's runtime dependencies
for dep in detect-libc semver; do
  if [ -d "node_modules/$dep" ] && [ ! -d "$NEXT_DIR/node_modules/$dep" ]; then
    cp -r "node_modules/$dep" "$NEXT_DIR/node_modules/$dep"
  fi
done
mkdir -p "$NEXT_DIR/node_modules/@img"
if [ -d "node_modules/@img/colour" ]; then
  cp -r node_modules/@img/colour "$NEXT_DIR/node_modules/@img/colour"
fi

# Remove any prebuilt platform binaries (we use source-built sharp + system libvips)
rm -rf "$NEXT_DIR/node_modules/@img/sharp-linux-x64"
rm -rf "$NEXT_DIR/node_modules/@img/sharp-libvips-linux-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-linux-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-libvips-linux-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-linuxmusl-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-libvips-linuxmusl-x64"
