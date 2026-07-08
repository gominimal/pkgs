#!/bin/bash
set -euo pipefail

# Sandbox doesn't have a cc symlink; point to gcc for native addon compilation
export CC=gcc
export CXX=g++

# Install all dependencies using the repo's pnpm-lock.yaml for reproducibility.
# The lockfile pins exact versions of every transitive dependency used during the build.
pnpm install --frozen-lockfile

# --- Reproducibility patches to the extracted source, before building --------
# L3 (the blocker): next overrides rspack's production-default moduleIds from
# 'deterministic' to 'named' in the runtime webpack configs. With 'named', the
# externalized trace/tracer module is keyed by whichever importer's relative
# request ('./lib/...' vs '../lib/...') rspack processes first — unstable under
# parallel module processing — cascading through the minified
# dist/compiled/next-server/*.runtime.prod.js. Restore the deterministic default.
sed -i "s/moduleIds: 'named',/moduleIds: 'deterministic',/" \
  packages/next/next-runtime.webpack-config.js \
  packages/next/next-devtools.webpack-config.js
for file in \
  packages/next/next-runtime.webpack-config.js \
  packages/next/next-devtools.webpack-config.js
do
  grep -q "moduleIds: 'deterministic'" "$file" \
    || { echo "ERROR: next moduleIds repro patch did not apply in $file (webpack config changed upstream)" >&2; exit 1; }
done

# L2: the bundle-analyzer fixture app is built during the build and bakes a
# random Next.js buildId (nanoid) into dist/bundle-analyzer/* and the
# _next/static/<buildId>/ dir names. Pin it deterministically.
sed -i "s/output: 'export',/output: 'export', generateBuildId: () => 'minimal-reproducible-build',/" \
  apps/bundle-analyzer/next.config.mjs
grep -q "minimal-reproducible-build" apps/bundle-analyzer/next.config.mjs \
  || { echo "ERROR: next bundle-analyzer generateBuildId repro patch did not apply" >&2; exit 1; }

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

# sharp discovers our system libvips via `pkg-config vips-cpp`, but libvips's public
# header <vips/vips8> #includes <glib-object.h> while vips-cpp.pc lists glib only under
# Requires.private. A non-static `pkg-config --cflags/--libs vips-cpp` (what sharp's
# node-gyp build uses) does not expand private requires, so glib's include/link paths
# are never passed and the addon FTBFS on "glib-object.h: No such file". Surface glib's
# include/lib dirs explicitly. CPATH/LIBRARY_PATH are read by gcc directly (independent
# of node-gyp's Makefile flag handling); CXXFLAGS/LDFLAGS cover the conventional path.
glib_inc=""
for i in $(pkg-config --cflags-only-I glib-2.0 gobject-2.0); do
  glib_inc="${glib_inc:+$glib_inc:}${i#-I}"
done
export CPATH="${glib_inc}${CPATH:+:$CPATH}"
export LIBRARY_PATH="/usr/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
glib_cflags="$(pkg-config --cflags glib-2.0 gobject-2.0)"
glib_libs="$(pkg-config --libs glib-2.0 gobject-2.0)"
export CFLAGS="${CFLAGS:-} ${glib_cflags}"
export CXXFLAGS="${CXXFLAGS:-} ${glib_cflags}"
export LDFLAGS="${LDFLAGS:-} ${glib_libs}"

node install/build.js

# Clean up native build artifacts, keeping ONLY the final .node addon — the rest
# of src/build is node-gyp scaffolding (Makefile, *.mk, config.gypi) that bakes
# the random $(mktemp -d) staging path into cmd_regen_makefile / compile lines.
if [ -d src/build ]; then
  find src/build -mindepth 1 -maxdepth 1 ! -name Release -exec rm -rf {} +
  if [ -d src/build/Release ]; then
    find src/build/Release -mindepth 1 -maxdepth 1 ! -name '*.node' -exec rm -rf {} +
  fi
fi

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
