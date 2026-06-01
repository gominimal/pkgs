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

# ZigGeneratedClasses.cpp — bun's largest generated C++ TU — hangs clang
# for HOURS at [656/669] on our toolchain (15h+, full 128G VM, no sandbox
# cap). Per-file -O1 (via extraFlagsFor) was applied but did NOT clear it,
# so the hang is almost certainly opt-INDEPENDENT (a clang frontend/sema
# blowup), not the -O3 optimizer. DECISIVE probe: drop the GLOBAL release
# opt -O3 -> -O0 in flags.ts (no per-file override, so EVERY core TU incl.
# ZigGeneratedClasses compiles at -O0). Builds → it was optimization after
# all (tune back up later); still hangs at -O0 → definitively frontend,
# opt-tuning is a dead end. Fail-loud if the -O3 entry is gone/renamed so
# we never silently build the hanging -O3.
perl -pi -e 's/flag: "-O3"/flag: "-O0"/' scripts/build/flags.ts
! grep -q 'flag: "-O3"' scripts/build/flags.ts \
  || { echo "FATAL: global -O3->-O0 patch did not apply (bun flags.ts release -O3 entry changed?)" >&2; exit 1; }

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

# Build via bun's own build orchestration (handles bun install, codegen, cmake
# deps, zig, linking, and strip). Outputs the stripped binary at build/release/bun.
bun run build:release

# Install
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 build/release/bun "$OUTPUT_DIR/usr/bin/bun"
ln -s bun "$OUTPUT_DIR/usr/bin/bunx"
