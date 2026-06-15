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

# #47: pin packages/app's `ghostty-web: github:...#main` BRANCH ref to the
# lockfile-resolved COMMIT (#20bd361). bun re-resolves a branch ref's HEAD over
# the network on every install (even --frozen-lockfile, even with the commit
# pinned in bun.lock and node_modules present) -> blackholed connect() -> hang
# at "Resolving dependencies". A commit ref is immutable, so bun trusts the
# lockfile entry (no network). The commit matches bun.lock's resolved
# `ghostty-web@github:anomalyco/ghostty-web#20bd361` so --frozen stays happy.
sed -i 's|github:anomalyco/ghostty-web#main|github:anomalyco/ghostty-web#20bd361|' packages/app/package.json
grep -q 'ghostty-web#20bd361' packages/app/package.json || { echo "FATAL #47: ghostty-web branch pin failed" >&2; exit 1; }

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

# The tarball ALSO carries bun's install cache (.bun-install-cache: registry
# manifests + git/url dep tarballs) — point bun at it. node_modules ALONE is
# insufficient for this workspace: it has a `catalog` (ulid, drizzle-orm, …) and
# git/url deps (ghostty-web#main, @solidjs/start@pkg.pr.new), and bun re-fetches
# the catalog MANIFESTS + git/url TARBALLS during "Resolving dependencies" on
# every install — even --frozen-lockfile, even with node_modules present (proven
# via `container run --network none`). The cache supplies them OFFLINE.
export BUN_INSTALL_CACHE_DIR="$PWD/.bun-install-cache"
[ -d "$BUN_INSTALL_CACHE_DIR" ] || { echo "FATAL #47: opencode .bun-install-cache missing in tarball" >&2; exit 1; }
echo "[opencode build.sh] bun install cache: $(du -sh "$BUN_INSTALL_CACHE_DIR" 2>/dev/null | cut -f1)"

# --filter=opencode scopes the install to the CLI subtree (opencode doesn't need
# packages/app or the web apps). Kept as defense-in-depth; the cache above is the
# actual offline fix. (Doesn't trip --frozen-lockfile — scoping ≠ workspaces edit.)
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
