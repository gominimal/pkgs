#!/bin/bash
set -euo pipefail

# Sandbox doesn't have a cc symlink; point to gcc for native addon compilation
export CC=gcc
export CXX=g++

# Hermetic build: when /pnpm-store exists (mounted by a SLSA-grade
# builder that has pre-staged the deps via `pnpm fetch` against this
# pkg's lockfile), redirect pnpm to that store and run offline.
# Otherwise fall back to the normal online install for dev iteration.
#
# Corepack auto-pin trap: next's package.json declares
# `"packageManager": "pnpm@9.6.0"`. The FIRST `pnpm` invocation
# triggers corepack to try installing that exact version via
# `pnpm add pnpm@9.6.0 --config.bin=bin …`, which looks in
# /pnpm-store, fails (the store is for next's lockfile deps,
# not for pnpm itself), and with COREPACK_ENABLE_NETWORK=0 there's
# no fallback. Result: `pnpm --version` exits 1 BEFORE we even
# get to the sed-fixup. Caught 2026-05-26.
#
# Fix: strip the packageManager field from package.json FIRST so
# corepack has nothing to auto-pin against; the builder-image-
# resident pnpm handles the install. Same shape as opencode's
# bun-version-pin removal trick.
#
# Engines.pnpm trap (second layer, caught 2026-05-26 after the
# corepack fix unmasked it): even with packageManager stripped, pnpm
# itself does an ERR_PNPM_UNSUPPORTED_ENGINE check against the
# package.json `engines.pnpm` field. next's package.json pins
# `"engines": { "pnpm": "9.6.0" }`; the builder image's pnpm is
# 10.x. Fix is to also pass --config.engine-strict=false to bypass
# the check. (Stripping the engines field too would also work but is
# more invasive to upstream package.json structure.)
if [ -d /pnpm-store ]; then
    export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
    export COREPACK_ENABLE_NETWORK=0
    # Drop the entire packageManager line (with trailing comma if
    # present) BEFORE any pnpm call. Idempotent + non-fatal.
    sed -i 's/^\s*"packageManager":\s*"pnpm@[^"]*",\?\s*$//' package.json || true
    pnpm install --offline --frozen-lockfile --store-dir=/pnpm-store --config.engine-strict=false
else
    pnpm install --frozen-lockfile --config.engine-strict=false
fi

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
