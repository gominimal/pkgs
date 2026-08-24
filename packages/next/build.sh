#!/bin/bash
set -euo pipefail

# [orch:corepack-neutralize] Upstream package.json may pin
# `packageManager: pnpm@X` / `engines.pnpm`, which makes corepack try to
# self-provision that exact pnpm — fatal offline (no network in the CS
# builder). Strip both + disable corepack's project-spec so the builder-
# resident pnpm is used regardless of what upstream pins. Idempotent +
# non-fatal; node is on PATH (it's the pkg's runtime).
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
export COREPACK_ENABLE_NETWORK=0
export COREPACK_ENABLE_PROJECT_SPEC=0
if [ -f package.json ] && command -v node >/dev/null 2>&1; then
    # #53 (2026-06-17): do NOT strip packageManager — turbo REQUIRES it ("Missing
    # packageManager field in package.json"). We bypass corepack entirely via the
    # explicit $PNPM (node pnpm.cjs) + COREPACK_ENABLE_PROJECT_SPEC=0, so keeping the
    # field is safe AND turbo reads it. Only drop engines.pnpm (engine-strict=false
    # also covers it; belt-and-suspenders against ERR_PNPM_UNSUPPORTED_ENGINE).
    node -e 'const f="package.json",fs=require("fs"),p=JSON.parse(fs.readFileSync(f));if(p.engines)delete p.engines.pnpm;fs.writeFileSync(f,JSON.stringify(p,null,2))' || true
fi

# Sandbox doesn't have a cc symlink; point to gcc for native addon compilation
export CC=gcc
export CXX=g++

# #53: next pins pnpm@9.6.0 and its lockfile is authored by it. Use that EXACT
# pnpm — any pnpm 10.x re-resolves the 9.6.0 lockfile differently, so the offline
# store (staged with 9.6.0 by the fetcher, which now honors packageManager) would
# miss what 10.x wants. The pnpm-9.6.0 npm tarball is a build input (build.ncl
# Source) hydrated to /build; it's a self-contained bundled CLI run via node.
# Falls back to the image pnpm for dev (no tarball present).
PNPM_TGZ="$(ls /build/pnpm-*.tgz 2>/dev/null | head -1)"
if [ -n "$PNPM_TGZ" ]; then
    mkdir -p /tmp/pnpm-pinned
    tar -xzf "$PNPM_TGZ" -C /tmp/pnpm-pinned
    PNPM="node /tmp/pnpm-pinned/package/bin/pnpm.cjs"
    echo "[next build.sh] pinned pnpm: $($PNPM --version) (from $PNPM_TGZ)"
    # #53 (2026-06-17): turbo runs each workspace pkg's build via `pnpm run build`,
    # resolving `pnpm` from PATH (= the builder's pnpm 10.x). pnpm 10.x sees the
    # packageManager:pnpm@9.6.0 pin and AUTO-PROVISIONS 9.6.0 (`pnpm add pnpm@9.6.0`
    # → fetch registry.npmjs.org/pnpm → offline → ERR_PNPM_META_FETCH_FAIL, failing
    # every turbo task). Put OUR pnpm 9.6.0 on PATH as `pnpm` so it ALREADY matches
    # the pin → no auto-switch. (Belt: also disable pnpm's version management.)
    mkdir -p /tmp/pnpm-bin
    printf '#!/bin/sh\nexec node /tmp/pnpm-pinned/package/bin/pnpm.cjs "$@"\n' > /tmp/pnpm-bin/pnpm
    chmod +x /tmp/pnpm-bin/pnpm
    export PATH="/tmp/pnpm-bin:$PATH"
    export npm_config_manage_package_manager_versions=false
else
    PNPM="pnpm"
fi

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
    # #53 (2026-06-17): do NOT strip packageManager — turbo REQUIRES it. corepack is
    # neutralized via COREPACK_ENABLE_PROJECT_SPEC=0 and we use the explicit $PNPM
    # (node pnpm.cjs), so the field is safe to keep and turbo reads it for `turbo run`.
    # pnpm 10.x STILL enforces engines.pnpm even with engine-strict=false
    # (ERR_PNPM_UNSUPPORTED_ENGINE: expected 9.6.0, got 10.x — caught
    # 2026-06-01). Strip the engines.pnpm pin too. Use node for a safe
    # JSON edit (no dangling-comma risk a sed would have). Idempotent +
    # non-fatal; node is on PATH (it's next's runtime).
    node -e 'const fs=require("fs"),p=JSON.parse(fs.readFileSync("package.json"));if(p.engines)delete p.engines.pnpm;fs.writeFileSync("package.json",JSON.stringify(p,null,2))' || true
    # Copy the RO cs-mirror store to writable scratch: pnpm symlinks the
    # project into <store>/<v>/projects/ on install → EROFS on the RO mount.
    PNPM_STORE_RW=/tmp/pnpm-store-rw; cp -r /pnpm-store "$PNPM_STORE_RW"
    # --no-frozen-lockfile: next's committed pnpm-lock.yaml was generated by a
    # pnpm whose built-in packageExtensions differ from the builder's pnpm
    # 10.33.0 → --frozen-lockfile fails ERR_PNPM_LOCKFILE_CONFIG_MISMATCH on
    # packageExtensionsChecksum. --offline keeps it hermetic (pnpm can only use
    # the pre-staged store, no network), so relaxing frozen just lets pnpm
    # reconcile the checksum against its own version — identical resolved deps.
    # --frozen-lockfile (was --no-frozen): with next's PINNED pnpm 9.6.0 the
    # lockfile is accepted as-is (no ERR_PNPM_LOCKFILE_CONFIG_MISMATCH — that only
    # hit pnpm 10.x) and resolution is lockfile-EXACT, matching the 9.6.0 store.
    # --ignore-scripts (CRITICAL, #53 root cause 2026-06-17): the staged store is
    # built with `pnpm install --ignore-scripts`, so git-source deps (watson/ci-info
    # from codeload) are stored "integrity-not-built". WITHOUT --ignore-scripts here,
    # pnpm tries to BUILD the git dep (run its prepare script) → needs to fetch the
    # source → offline → ERR_PNPM_NO_OFFLINE_TARBALL. Matching the staging flag makes
    # the install consume the not-built store entry as-is. Reproduced + confirmed
    # locally: `cp -r store + pnpm install --offline --frozen --ignore-scripts` = all
    # 3832 pkgs incl ci-info resolve.
    $PNPM install --offline --frozen-lockfile --ignore-scripts --store-dir="$PNPM_STORE_RW" --config.engine-strict=false
else
    $PNPM install --frozen-lockfile --config.engine-strict=false
fi

# Build next and all its workspace dependencies (e.g. @next/env)
$PNPM exec turbo run build --filter=next...

# Pack our source-built next into a tarball (resolves workspace: protocols to real
# versions). The OUTPUT install below installs THIS tarball via npm (offline).
WS_ROOT="$PWD"
cd packages/next
$PNPM pack --pack-destination /tmp
cd "$WS_ROOT"

# Strip OPTIONAL peerDependencies from the workspace packages before deploy.
# ROOT CAUSE (validated with a faithful container repro of the exact error): next
# declares @playwright/test (and sass, @opentelemetry/api, babel-plugin-react-compiler)
# as BOTH an exact devDependency AND an optional peerDependency (a range, e.g.
# ^1.51.1). `pnpm deploy --prod` drops the devDependency that was satisfying the
# range, orphaning the optional peer → deploy then RE-RESOLVES the range, which needs
# registry METADATA the offline store doesn't carry → ERR_PNPM_NO_OFFLINE_META. (The
# install passed because --frozen-lockfile never re-resolves.) These peers are
# optional + consumer-supplied; the output next CLI doesn't need them declared (next
# require()s them in try/catch). Removing the optional-peer DECLARATION makes deploy
# skip resolving them; --frozen-lockfile still drives the real deps from the lockfile.
# Container-verified: A) baseline --prod --frozen → NO_OFFLINE_META; C) optional peer
# stripped → deploy succeeds offline with the metadata cache absent. --no-optional did
# NOT help (it skips optionalDependencies, not optional peers).
for pj in packages/*/package.json; do
  [ -f "$pj" ] || continue
  node -e 'const fs=require("fs"),f=process.argv[1],p=JSON.parse(fs.readFileSync(f));const m=p.peerDependenciesMeta||{};let ch=false;for(const k of Object.keys(m)){if(m[k]&&m[k].optional){if(p.peerDependencies)delete p.peerDependencies[k];delete m[k];ch=true;}}if(ch)fs.writeFileSync(f,JSON.stringify(p,null,2));' "$pj" || true
done

# Assemble next + its runtime deps into the output, OFFLINE. The former
# `npm install -g "/tmp/next-$VERSION.tgz"` re-resolves next's runtime deps
# (@next/env, styled-jsx, postcss, caniuse-lite, …) from registry.npmjs.org →
# offline → ERR ETIMEDOUT: npm cannot read the pnpm store the workspace install
# populated. pnpm deploy copies the BUILT `next` workspace package + its prod
# deps straight out of the (offline) virtual store into the target, placing deps
# NESTED under next/node_modules — exactly the layout the build.ncl output glob
# (usr/lib/node_modules/next/**) and the bin shim (usr/bin/next) expect.
# --prod: runtime deps only (react/react-dom are peerDeps, supplied by the app).
# --frozen-lockfile (CRITICAL): WITHOUT it, deploy RE-RESOLVES next's dep graph and
# needs registry METADATA to pick versions for RANGE deps (e.g. the devDep
# @playwright/test@>=1.51.1) → offline → ERR_PNPM_NO_OFFLINE_META (the metadata
# mirror only has tarballs staged, not metadata — the --frozen install never
# fetched any). --frozen-lockfile uses the lockfile's already-pinned resolution
# (verified locally: "resolved 0" with the metadata cache fully deleted → zero
# metadata needed) and --prod still prunes the dev range deps. NOTE: pnpm 9.6.0
# deploy IS the legacy assembler by default — NO --legacy flag (that's pnpm 10.x;
# passing it = "ERROR Unknown option: 'legacy'"). Offline branch mirrors the
# install: --offline + the same writable store → zero network egress (the bun lesson).
# --ignore-scripts (same reason as the install above): the staged store holds
# git-source deps (watson/ci-info from codeload) as "integrity-not-built". Without
# it, deploy tries to BUILD the git dep → fetch its source → offline →
# ERR_PNPM_NO_OFFLINE_TARBALL. Matching the install's flag makes deploy consume the
# not-built entry as-is.
# --config.auto-install-peers=false (CRITICAL): with the default (true), deploy
# auto-installs next's PEER deps (react, react-dom, …) into the output and resolves
# THEIR transitive deps fresh — e.g. react-dom@19.x-canary → scheduler@0.28-canary —
# needing registry metadata absent offline → ERR_PNPM_NO_OFFLINE_META. Peers are
# consumer-supplied; the output next CLI must NOT bundle/resolve them. Disabling
# auto-install-peers skips the entire peer subtree (this also covers the optional
# peers; the strip loop above is belt-and-suspenders). Container-verified: required
# peer present → NO_OFFLINE_META; with auto-install-peers=false → deploy succeeds.
NEXT_DIR="$OUTPUT_DIR/usr/lib/node_modules/next"
# Install our source-built next (the packed tarball) + runtime deps OFFLINE via npm.
# PIVOTED off `pnpm deploy`: deploy RE-RESOLVES next's dep graph against the offline
# pnpm store (tarballs only, NO metadata) → endless ERR_PNPM_NO_OFFLINE_META on ranged
# deps (optional peers → react-dom/scheduler → @vercel/routing-utils→path-to-regexp).
# `npm install -g <tarball>` resolves ONLY next's `dependencies` (peers just WARN+skip)
# from the npm cache, which carries packuments AND tarballs — self-sufficient offline.
# Container-validated: `npm install -g <tarball> --offline` → added 22 packages,
# `next --version` → "Next.js v16.2.6". npm nests deps under next/node_modules (matches
# the build.ncl usr/lib/node_modules/next/** glob) + auto-creates usr/bin/next.
if [ -d /npm-cache ]; then
    # /npm-cache is RO and npm's cacache writes bookkeeping even on --offline reads,
    # so copy to writable scratch first (same idiom as the sharp block below).
    NEXT_NPM_CACHE_RW=/tmp/next-output-npm-cache
    cp -r /npm-cache "$NEXT_NPM_CACHE_RW"
    npm install -g --offline --cache="$NEXT_NPM_CACHE_RW" --prefix="$OUTPUT_DIR/usr" --no-audit --no-fund "/tmp/next-$MINIMAL_ARG_VERSION.tgz"
else
    npm install -g --prefix="$OUTPUT_DIR/usr" "/tmp/next-$MINIMAL_ARG_VERSION.tgz"
fi

# Build sharp from source against our system libvips
SHARP_STAGING=$(mktemp -d)
cd "$SHARP_STAGING"
echo '{"private":true}' > package.json

# Install sharp without scripts (skip prebuilt download), then compile native addon.
# Use npm here (not pnpm) so node_modules is flat, avoiding pnpm symlinks in the output.
# Hermetic: when an npm cache is mounted (pre-staged sharp + node-addon-api +
# node-gyp), install offline. /npm-cache is read-only and npm's cacache writes
# bookkeeping even on --offline reads, so copy to a writable scratch dir first
# (same idiom as typescript-language-server). Falls back to online for dev.
if [ -d /npm-cache ]; then
    NPM_CACHE_RW=/tmp/sharp-npm-cache
    cp -r /npm-cache "$NPM_CACHE_RW"
    npm install --ignore-scripts --offline --cache="$NPM_CACHE_RW" sharp node-addon-api node-gyp
else
    npm install --ignore-scripts sharp node-addon-api node-gyp
fi
export PATH="$SHARP_STAGING/node_modules/.bin:$PATH"
cd node_modules/sharp
# node-gyp compiles sharp's native addon and by DEFAULT downloads node's C++
# headers (node-v$VER-headers.tar.gz) from nodejs.org — fatal offline in the CS
# builder (gyp ERR! AggregateError [ETIMEDOUT], caught 2026-06-18). Our `node`
# artifact is a runtime dep of next, so its full /usr tree is hydrated into the
# sandbox, and node's `make install` ships the headers + common.gypi to
# /usr/include/node/. Point node-gyp there with --nodedir (read from
# npm_config_nodedir; sharp's install/build.js spawns node-gyp inheriting the
# env) so it uses the on-disk headers and skips the download entirely.
if [ -f /usr/include/node/node_version.h ]; then
    export npm_config_nodedir=/usr
    echo "[next build.sh] node-gyp nodedir=/usr ($(ls /usr/include/node/*.h 2>/dev/null | wc -l) headers on disk)"
else
    echo "[next build.sh] WARN: /usr/include/node/ headers absent — node-gyp will attempt a download (offline → ETIMEDOUT)"
fi
node install/build.js

# Clean up native build artifacts, keeping only the final .node addon
find src/build -name '*.o' -delete
rm -rf src/build/Release/obj.target
rm -rf src/build/Release/.deps

# Copy the source-built sharp into next's node_modules. NEXT_DIR now comes from
# `pnpm deploy` (symlink layout: deps live under next/node_modules/.pnpm with
# top-level symlinks). next doesn't depend on sharp directly so deploy shouldn't
# place one here, but remove any pre-existing entry first: `cp -r SRC DEST` into a
# symlink-to-dir would nest wrongly (DEST/sharp). rm runs in the CS sandbox.
cd "$SHARP_STAGING"
rm -rf "$NEXT_DIR/node_modules/sharp"
cp -r node_modules/sharp "$NEXT_DIR/node_modules/sharp"

# Copy sharp's runtime dependencies
for dep in detect-libc semver; do
  if [ -d "node_modules/$dep" ] && [ ! -d "$NEXT_DIR/node_modules/$dep" ]; then
    cp -r "node_modules/$dep" "$NEXT_DIR/node_modules/$dep"
  fi
done
mkdir -p "$NEXT_DIR/node_modules/@img"
if [ -d "node_modules/@img/colour" ]; then
  rm -rf "$NEXT_DIR/node_modules/@img/colour"
  cp -r node_modules/@img/colour "$NEXT_DIR/node_modules/@img/colour"
fi

# Remove any prebuilt platform binaries (we use source-built sharp + system libvips)
rm -rf "$NEXT_DIR/node_modules/@img/sharp-linux-x64"
rm -rf "$NEXT_DIR/node_modules/@img/sharp-libvips-linux-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-linux-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-libvips-linux-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-linuxmusl-x64"
rm -rf "$NEXT_DIR/node_modules/sharp/node_modules/@img/sharp-libvips-linuxmusl-x64"
