#!/bin/sh
set -ex

# ─── Seed bun's tarball cache from pre-staged Source deps ─────────────
# bun's scripts/build/fetch-cli.ts caches github archive downloads at
# /state/home/.bun/build-cache/tarballs/<name>-<urlHash:16>.tar.gz where
# urlHash = sha256(url)[:16]. If the file already exists, fetch-cli
# skips the network call. We pre-stage 18 deps via Source build_deps
# (extract=false) so they land at /build/<basename>; copy each into
# the cache at the path fetch-cli expects.
#
# url_hash16 values are sha256(url)[:16]; computed offline from
# `orch discover-bun --remote` output. If you bump a dep commit/tag in
# scripts/build/deps/*.ts, re-discover and update the entry below.
BUN_CACHE_DIR=/state/home/.bun/build-cache/tarballs
mkdir -p "$BUN_CACHE_DIR"

seed_bun_dep() {
  name=$1 src_basename=$2 url_hash=$3
  if [ -f "$src_basename" ]; then
    cp "$src_basename" "$BUN_CACHE_DIR/${name}-${url_hash}.tar.gz"
  else
    echo "WARN: bun dep source missing at /build/$src_basename" >&2
  fi
}
seed_bun_dep libdeflate     c8c56a20f8f621e6a966b716b31f1dedab6a41e3.tar.gz ce0e2d9805b30dcc
seed_bun_dep picohttpparser 066d2b1e9ab820703db0837a7255d92d30f0c9f5.tar.gz fad59b16ad4752cc
seed_bun_dep zstd           f8745da6ff1ad1e7bab384bd1f9d742439278e99.tar.gz e010993a24072468
seed_bun_dep lshpack        8905c024b6d052f083a3d11d0a169b3c2735c8a1.tar.gz 73e0c55d12ea4fc2
seed_bun_dep brotli         v1.1.0.tar.gz                                   723494d4c3a9902a
seed_bun_dep lolhtml        77127cd2b8545998756e8d64e36ee2313c4bb312.tar.gz 929339b1d898e66b
seed_bun_dep highway        ac0d5d297b13ab1b89f48484fc7911082d76a93f.tar.gz a10c8937e1b920ad
seed_bun_dep libuv          f3ce527ea940d926c40878ba5de219640c362811.tar.gz 79859fcef81beb7f
seed_bun_dep tinycc         12882eee073cfe5c7621bcfadf679e1372d4537b.tar.gz 2f1f629056328c7b
seed_bun_dep zlib           12731092979c6d07f42da27da673a9f6c7b13586.tar.gz 655c6ecdb6fc9cd5
seed_bun_dep boringssl      0c5fce43b7ed5eb6001487ee48ac65766f5ddcd1.tar.gz 5e15ff9594809574
seed_bun_dep mimalloc       57029fb1f193e633462e76af745599e1dbfd4b58.tar.gz 6d6e156271bd6c93
seed_bun_dep cares          3ac47ee46edd8ea40370222f91613fc16c434853.tar.gz 4e43539b43c0f4ae
seed_bun_dep hdrhistogram   be60a9987ee48d0abf0d7b6a175bad8d6c1585d1.tar.gz 97084f213075a65e
seed_bun_dep libarchive     ded82291ab41d5e355831b96b0e1ff49e24d8939.tar.gz 4296b191210d6b1b

# ─── Seed bun's PREBUILT cache (nodejs headers, WebKit, zig) ─────────
# Unlike the dep-kind tarballs above, the prebuilt/zig fetch kinds cache
# an EXTRACTED directory + a stamp file. Reverse-engineered from bun
# 1.3.13 scripts/build/{download,nodejs-headers,webkit,zig}.ts:
#   - extract the archive, HOIST the single top-level dir into <dest>
#     (== tar --strip-components=1)
#   - write <dest>/.identity = "<identity>\n"   (zig: <dest>/.zig-commit)
#   - bun skips the network fetch when readFile(stamp).trim()==identity
# The prebuilt cache lives under bun's build-cache (env-wired), the same
# root the tarballs/ dir above sits in. If the build log STILL shows a
# `fetching <name>` line for any of these, it prints the exact dest +
# identity it wants — match it here (likely suspects: the WebKit suffix
# -lto vs none, or a zig `-safe` stamp suffix, depending on build mode).
BUN_BUILD_CACHE=/state/home/.bun/build-cache

seed_bun_prebuilt_tar() {
  dest=$1 identity=$2 src=$3; shift 3
  if [ ! -f "$src" ]; then echo "WARN: bun prebuilt source missing: /build/$src" >&2; return; fi
  rm -rf "$dest"; mkdir -p "$dest"
  # --no-same-owner: the unprivileged sandbox forbids chown, so tar's
  # default ownership-restore fails ("Cannot change ownership ...
  # Invalid argument"). Same idiom ca-certificates uses.
  tar --no-same-owner -xzf "$src" -C "$dest" --strip-components=1
  for rmp in "$@"; do rm -rf "$dest/$rmp"; done
  printf '%s\n' "$identity" > "$dest/.identity"
}

# nodejs headers: dest=<cache>/nodejs-headers-<ver>, identity=<ver>;
# bun deletes the bundled openssl/uv headers post-extract.
seed_bun_prebuilt_tar "$BUN_BUILD_CACHE/nodejs-headers-24.3.0" "24.3.0" \
  node-v24.3.0-headers.tar.gz \
  include/node/openssl include/node/uv include/node/uv.h

# WebKit: bun's build:release uses the NON-LTO cache key (confirmed from
# the build log 2026-05-30): dest=<cache>/webkit-<commit[:16]> (no
# suffix), identity=<full commit> (no suffix), source
# bun-webkit-linux-amd64.tar.gz. build.ncl must stage the NON-LTO tarball
# to match this basename + provide the right libs.
seed_bun_prebuilt_tar \
  "$BUN_BUILD_CACHE/webkit-4d5e75ebd84a14ed" \
  "4d5e75ebd84a14edbc7ae264245dcd77fe597c10" \
  bun-webkit-linux-amd64.tar.gz

# zig: dest=<bun-src>/vendor/zig, stamp=.zig-commit=<commit>. It's a
# .zip with a single top-level dir to hoist; must yield ./zig + ./lib.
if [ -f bootstrap-x86_64-linux-musl.zip ]; then
  rm -rf vendor/zig _zigtmp
  mkdir -p _zigtmp vendor
  unzip -q -o bootstrap-x86_64-linux-musl.zip -d _zigtmp
  ztop=$(ls _zigtmp)
  if [ "$(printf '%s\n' "$ztop" | wc -l)" -eq 1 ] && [ -d "_zigtmp/$ztop" ]; then
    mv "_zigtmp/$ztop" vendor/zig
  else
    mv _zigtmp vendor/zig
  fi
  rm -rf _zigtmp
  printf '%s\n' "365343af4fc5a1a632e6b54aadd0b87be30edd81" > vendor/zig/.zig-commit
else
  echo "WARN: bun zig bootstrap zip missing: /build/bootstrap-x86_64-linux-musl.zip" >&2
fi

# Extract and set up bootstrap bun binary
case $(uname -m) in
  x86_64)  BUN_ARCH=x64;   CARGO_TARGET=x86_64-unknown-linux-gnu ;;
  aarch64) BUN_ARCH=aarch64; CARGO_TARGET=aarch64-unknown-linux-gnu ;;
esac
unzip -o "bun-linux-${BUN_ARCH}.zip"
chmod +x "bun-linux-${BUN_ARCH}/bun"
export PATH="$(pwd)/bun-linux-${BUN_ARCH}:$PATH"
bun --version

# Set compilers to use LLVM/Clang
export CC=clang
export CXX=clang++

# NOTE: bun's two JSC "touch-every-generated-class" TUs (ZigGeneratedClasses.cpp +
# ZigGlobalObject.cpp) hang clang for HOURS at ~[656/669] when the JSC PCH is layered
# on. Root-caused 2026-06-10 to the PCH (NOT the optimizer — a global -O0 probe also
# wedged ~148m). Fixed below by a per-file PCH exclusion (search "per-file PCH
# exclusion"). See memory bun_o0_verdict_frontend for the full analysis.

# Ensure Cargo/Rust can find the C compiler and linker
# (Cargo looks for "cc" by default which may not exist)
export "CARGO_TARGET_$(echo $CARGO_TARGET | tr 'a-z-' 'A-Z_')_LINKER=clang"

# Optimization flags
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Remove rust-toolchain.toml to avoid rustup nightly requirement;
# our stable rust is sufficient for lol-html
rm -f rust-toolchain.toml

# Initialize a git repo so nested dep version generation works
# (it runs "git rev-parse HEAD" to get version strings for bundled packages)
git init -q
git -c user.email=build@local -c user.name=build commit -q -m "v${MINIMAL_ARG_VERSION}" --allow-empty

# lolhtml's c-api is the one dep bun builds via cargo (it needs
# encoding_rs + 42 transitive crates). Stage those offline: extract the
# pre-vendored crate set, point crates.io at it via a global cargo
# config, and force CARGO_NET_OFFLINE so the cargo build never reaches
# the network. lolhtml is the only cargo build in bun, so a global
# redirect is safe.
if [ -f lolhtml-capi-vendor.tar.zst ]; then
  LOLHTML_VENDOR=/build/lolhtml-capi-vendor
  mkdir -p "$LOLHTML_VENDOR"
  tar --no-same-owner -I 'zstd -d' -xf lolhtml-capi-vendor.tar.zst -C "$LOLHTML_VENDOR" --strip-components=1
  export CARGO_NET_OFFLINE=true
  export CARGO_HOME=/build/.cargo
  mkdir -p "$CARGO_HOME"
  cat > "$CARGO_HOME/config.toml" <<EOF
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "$LOLHTML_VENDOR"
EOF
else
  echo "WARN: lolhtml cargo-vendor tarball missing at /build/lolhtml-capi-vendor.tar.zst" >&2
fi

# ─── ZigGeneratedClasses.cpp.o hang (task #47) — per-file PCH exclusion ───
# ROOT CAUSE CONFIRMED (2 ultracode workflows + overnight 2026-06-10 on image
# f415508c): the hang is the JSC PCH. bun IGNORES env CXXFLAGS (flags baked into the
# ninja $cxxflags via flags.ts; minimal has no compiler wrapper) — so the old global
# -O0 probe never even reached this TU. Forcing usePch=false GLOBALLY PROVED it (the
# build compiled clean PAST ZigGeneratedClasses — the 2-day [656/669] wall is gone),
# but global no-PCH is NOT shippable: PCH is load-bearing for SPEED (no-PCH re-parses
# the whole JSC/WebKit header set per-TU → glacial, only 175/667 in 13h) AND it
# exposes -Werror=undefined-var-template in other TUs (JSBuffer.cpp: JSC s_info).
# FIX: keep the PCH for non-codegen TUs; exclude ALL codegen/*.cpp + ZigGlobalObject.cpp.
# (2026-06-11: started as "just the 2 hubs", but a THIRD codegen TU — GeneratedSSLConfig.cpp
# — wedged identically at [656/669] AFTER both hubs compiled clean. Rather than whack-a-mole
# each generated TU, exclude the whole codegen/ output dir: no-PCH is correct, just slower.)
# The original two hubs: ZigGeneratedClasses.cpp (DEFINES all generated
# classes, the 3.3MB monster) and ZigGlobalObject.cpp (wires EVERY lazy structure +
# DOM-isolated-subspace into the global object). ~80 other webcore/JS*.cpp pull in the
# same subspace headers but instantiate ONE class each → they compile fine WITH the PCH
# (all landed in [1..655]). Only these two "touch-everything" hubs blow up clang's
# sema/constexpr when the PCH (built with -fpch-instantiate-templates) is layered on.
# Confirmed empirically 2026-06-10: excluding ZigGeneratedClasses alone got the build to
# [656/669] = ZigGlobalObject, which then wedged ~35m+ identically → second hub, same fix.
# bun routes a file to cxx_pch iff opts.pch is set (compile.ts:195); gate that on the
# source NOT being either hub. The else-branch already wires the correct no-PCH dep
# tracking (implicitInputs=depHeaderSignal, orderOnlyInputs=codegenOrderOnly). usePch
# stays its normal TRUE → only the two hubs compile PCH-free (clean, ~minutes each),
# sidestepping both the slowness and the JSBuffer -Werror=undefined-var-template cascade.

# FIX: per-file PCH exclusion for the two JSC hub TUs. HARD-FAIL on drift.
python3 - scripts/build/bun.ts <<'PY'
import sys
f = sys.argv[1]; s = open(f).read()
old = '    if (pchOut !== undefined) {'
new = '    if (pchOut !== undefined && !relSrc.includes("codegen") && !relSrc.includes("ZigGlobalObject") && !relSrc.includes("crypto")) {'
assert s.count(old) == 1, "pchOut gate anchor not found/unique in scripts/build/bun.ts — bun version drift, re-derive"
open(f, "w").write(s.replace(old, new, 1))
print("[bun build.sh] per-file PCH exclusion: ALL codegen/*.cpp + ZigGlobalObject -> no-PCH cxx rule", file=sys.stderr)
PY

# FIX (#47, ROOT CAUSE — v2, PROVEN): the 3 build-time `bun install` ninja edges
# (codegen.ts bun_install rule -> root /build, packages/bun-error,
# src/node-fallbacks) HANG in the CS offline sandbox on a COLD npm install cache.
# bun gates network purely on cache presence (no offline flag helps), so a MISS
# issues a blackholed registry connect() and the HTTP thread parks in
# do_epoll_wait forever (proven 2026-06-14 with the real linux bun: cold cache +
# no net = hang; full cache + no net = offline install). --prefer-offline was
# REMOVED — ZERO readers under bun's src/install/ (Arguments.zig:105 is
# RUNTIME-only) so fix attempt #1 was a no-op. REAL fix = pre-seed the cache (the
# extract block below). This patch is the GUARDRAIL: --ignore-scripts (match the
# proven install) + `timeout 300` so any FUTURE cache miss fails LOUD in 5min
# instead of a multi-hour silent wedge (the per-recipe form of #57's fail-closed
# cache guard). HARD-FAIL on drift so a bun version bump can't silently un-patch.
python3 - scripts/build/codegen.ts <<'PY'
import sys
f = sys.argv[1]; s = open(f).read()
old = "${bun} install --frozen-lockfile && "
new = "timeout 300 ${bun} install --frozen-lockfile --ignore-scripts && "
assert s.count(old) == 2, f"bun_install edge anchor count={s.count(old)} != 2 in codegen.ts — bun drift, re-derive"
open(f, "w").write(s.replace(old, new))
print("[bun build.sh] bun_install edge -> --ignore-scripts + timeout 300 (cache pre-seeded; loud-fail on miss)", file=sys.stderr)
PY

# DIAGNOSTIC (#47) v2 — name-AGNOSTIC. The crack-bun ultracode workflow (2026-06-13)
# PROVED the [656/669] "wedge" was a MISREAD: ninja's [N/M] on a piped non-tty is a
# FINISHED-edges counter, so [656] ZigGeneratedClasses = COMPILED OK (all 557 cxx + 26
# cc edges finished; corroborated by the global-no-PCH run reaching a downstream JSBuffer
# -Werror). v1's pgrep name-pinned ZGC/ZigGlobalObject (already finished at [655]/[656])
# so it watched corpses and emitted nothing. The real long-pole is the downstream
# console-pool zig_build edge producing bun-zig.o (the whole Zig codebase via
# single-threaded LLVM codegen, zig.ts:407), which emits no ninja line (console pool +
# non-tty) and blocks the final lld link. clang/the toolchain are EXONERATED — do NOT
# rebuild llvm. This walks /proc every 90s for EVERY compiler/zig/link/wrapper proc:
# state, cpu ticks (rising=>busy), rss, threads, wchan+syscall (what it's blocked on),
# per-thread wchan for zig, plus bun-zig.o size + zig-cache growth — settles
# slow-vs-hung-vs-ninja-idle at the wall. Paired with `-v` so ninja names the stuck edge.
( BD=build/release
  while true; do
    sleep 90
    echo "=[bun-diag]= $(date +%T) snapshot"; any=0
    for d in /proc/[0-9]*; do
      c=$(cat "$d/comm" 2>/dev/null) || continue
      case "$c" in zig|clang*|clang++|cc1*|*lld*|ld.lld|ninja|bun|node|stream|sh) ;; *) continue ;; esac
      any=1; p=${d#/proc/}
      st=$(awk '{print $3}' "$d/stat" 2>/dev/null)
      cpu=$(awk '{print $14+$15+$16+$17}' "$d/stat" 2>/dev/null)
      rss=$(awk '/VmRSS/{print $2}' "$d/status" 2>/dev/null)
      thr=$(awk '/Threads/{print $2}' "$d/status" 2>/dev/null)
      wch=$(cat "$d/wchan" 2>/dev/null); sc=$(cut -d' ' -f1 "$d/syscall" 2>/dev/null)
      arg=$(tr '\0' ' ' <"$d/cmdline" 2>/dev/null | cut -c1-160)
      echo "=[bun-diag]= pid=$p comm=$c st=$st cpu=$cpu rssKB=${rss:-?} thr=${thr:-?} wchan=${wch:-run} sys=${sc:-?} :: $arg"
      if [ "$c" = zig ]; then for t in "$d"/task/*/wchan; do [ -e "$t" ] && echo "=[bun-diag]=   thr $(basename "$(dirname "$t")") wchan=$(cat "$t" 2>/dev/null)"; done; fi
    done
    [ "$any" = 0 ] && echo "=[bun-diag]= NO compiler/zig/link/ninja proc alive (ninja-idle / between edges)"
    echo "=[bun-diag]= bun-zig.o=$(ls -l $BD/bun-zig.o 2>/dev/null | awk '{print $5}' || echo absent) zigcache=$(du -sh $BD/.zig-cache 2>/dev/null | cut -f1)"
  done ) &
BUN_DIAG_PID=$!

# #47 ROOT-CAUSE FIX: pre-seed bun's npm INSTALL cache so the 3 bun_install ninja
# edges resolve OFFLINE instead of hanging on a blackholed registry connect. The
# bun-install-cache Source (extract=false) landed at /build/<basename>; extract it
# into BUN_INSTALL_CACHE_DIR (=/state/bun-cache via the recipe's env_state_wiring).
# Sentinel-check the two non-root edges' marker pkgs (preact=bun-error edge,
# esbuild@0.25.12=node-fallbacks edge) so a stale/incomplete cache fails LOUD HERE,
# not as a mid-build wedge. Validated offline 3/3 (2026-06-14, --no-dns).
CACHE_DST="${BUN_INSTALL_CACHE_DIR:-/state/bun-cache}"
CACHE_TAR="$(ls /build/bun-install-cache-*.tar.gz 2>/dev/null | head -1)"
[ -n "$CACHE_TAR" ] || { echo "FATAL #47: bun install-cache tarball missing in /build" >&2; exit 1; }
mkdir -p "$CACHE_DST"
tar -xzf "$CACHE_TAR" -C "$CACHE_DST"
echo "[bun build.sh] extracted $(basename "$CACHE_TAR") -> $CACHE_DST"
ls -d "$CACHE_DST"/preact@* >/dev/null 2>&1 || { echo "FATAL #47: preact (bun-error edge) missing from install-cache — re-stage the union cache" >&2; exit 1; }
ls -d "$CACHE_DST"/esbuild@0.25.12* >/dev/null 2>&1 || { echo "FATAL #47: esbuild@0.25.12 (node-fallbacks edge) missing from install-cache" >&2; exit 1; }

# Build via bun's own build orchestration (handles bun install, codegen, cmake deps,
# zig, linking, strip). `build:release` is exactly `bun scripts/build.ts
# --profile=release` (package.json); the trailing `-v` forwards through build.ts:12-16
# to ninja so the stuck edge prints its full command in ninja's own voice. Outputs the
# stripped binary at build/release/bun.
bun scripts/build.ts --profile=release -v

kill "$BUN_DIAG_PID" 2>/dev/null || true

# Install
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 build/release/bun "$OUTPUT_DIR/usr/bin/bun"
ln -s bun "$OUTPUT_DIR/usr/bin/bunx"
