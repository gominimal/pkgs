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
seed_bun_dep brotli         v1.1.0.tar.gz                                   16cc1f51604073f5
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

# nodejs-headers, webkit, zig use bun's `prebuilt` and `zig` fetch kinds
# rather than `dep` — different cache semantics (.identity stamp inside
# dest dir, not a tarball-in-cache). If the build fails on these, the
# follow-up is to write the .identity stamps directly. Leaving for a
# next pass since the dep-kind seeding gets us through ~15 of 18 fetches
# and is the dominant cost. Source build_deps for these 3 are still in
# build.ncl (sha-pinned in CAS) so they're hermetically available even
# if we have to write a different consume-path.

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

# Build via bun's own build orchestration (handles bun install, codegen, cmake
# deps, zig, linking, and strip). Outputs the stripped binary at build/release/bun.
bun run build:release

# Install
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 build/release/bun "$OUTPUT_DIR/usr/bin/bun"
ln -s bun "$OUTPUT_DIR/usr/bin/bunx"
