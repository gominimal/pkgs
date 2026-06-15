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

# #47: extract the pre-materialized node_modules (staged via
# `orch stage bun opencode --node-modules --use-fetcher`) so the install
# below is a NO-OP verify with ZERO network. A cold `bun install` always
# contacts the registry for metadata even with a populated cache ->
# blackholed connect() -> hang; only a lockfile-matching node_modules is
# offline-safe. opencode is a workspace monorepo, so the tarball carries
# the whole workspace tree (root + every packages/*/node_modules). We're
# cd'd into opencode-${VERSION}, so extract here with -C . (not /build).
NM_TAR="$(ls /build/opencode-allnm-*.tar.gz 2>/dev/null | head -1)"
[ -n "$NM_TAR" ] || { echo "FATAL #47: opencode node_modules tarball missing in /build" >&2; exit 1; }
tar --no-same-owner -xzf "$NM_TAR" -C .
echo "[opencode build.sh] pre-materialized node_modules ($(ls node_modules 2>/dev/null | wc -l) entries)"

# --filter=opencode: scope the install to the CLI workspace + its deps only.
# WITHOUT this, the root workspace install resolves packages/app, whose
# `ghostty-web: github:...#main` BRANCH dep bun re-validates over the network
# on every install (even --frozen-lockfile, even with node_modules present, even
# though the lockfile pins the commit) -> blackholed connect() -> hang at
# "Resolving dependencies". opencode (the CLI) doesn't depend on packages/app or
# the web apps' pkg.pr.new dep, so --filter excludes them entirely -> no
# git/url re-validation -> the pre-materialized node_modules makes it a no-op
# verify with zero network. (Proven locally: --filter=opencode leaves
# ghostty-web + @solidjs/start unresolved and doesn't trip --frozen-lockfile.)
bun install --frozen-lockfile --ignore-scripts --no-progress --filter=opencode

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
