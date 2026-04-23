#!/bin/sh
set -ex

# Upstream's tarball contains filenames with brackets (e.g. `[...callback].ts`)
# that trip the built-in extractor, so unpack with tar manually.
tar -xzf "v${MINIMAL_ARG_VERSION}.tar.gz"
cd "opencode-${MINIMAL_ARG_VERSION}"

# Relax the packageManager pin to whatever bun version pkgs ships.
# Upstream pins an exact version; the build script's version gate uses a ^range
# so rewriting the pin to match our shipped bun is sufficient.
bun_version="$(bun --version)"
sed -i "s/\"packageManager\": \"bun@[^\"]*\"/\"packageManager\": \"bun@${bun_version}\"/" package.json

# Install monorepo dependencies (requires network access).
bun install --frozen-lockfile --ignore-scripts

# The build script consults git for a channel name when these are unset;
# set them explicitly so it doesn't shell out to git in the sandbox.
export OPENCODE_VERSION="$MINIMAL_ARG_VERSION"
export OPENCODE_CHANNEL="local"

# Build a single-target native binary, matching the upstream nix recipe.
cd packages/opencode
bun --bun ./script/build.ts --single --skip-install

case "$(uname -m)" in
  x86_64)  DIST_ARCH=x64 ;;
  aarch64) DIST_ARCH=arm64 ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 "dist/opencode-linux-${DIST_ARCH}/bin/opencode" "$OUTPUT_DIR/usr/bin/opencode"
