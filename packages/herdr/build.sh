#!/bin/sh
# Auto-bootstrapped from https://github.com/herdrdev/herdr (0.9.1, rust) by pkgmgr import github.
set -eu
export CC=gcc
export LD=gcc
# Reproducibility (per minimal-repro's guide): strip absolute build
# paths (source dir + cargo registry) and disable incremental builds.
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
export CARGO_INCREMENTAL=0
# herdr vendors libghostty-vt, whose build.rs shells out to Zig and looks
# for it on PATH or via $ZIG. It pins Zig 0.16.0 and refuses anything else,
# so point it at the prefixed zig-0.16 line, not `zig` (0.17).
export ZIG=/usr/lib/zig-0.16/bin/zig
"$ZIG" version | grep -qx '0.16.0' || { echo "herdr: $ZIG is not zig 0.16.0" >&2; exit 1; }

# Offline zig packages (build.ncl `zig_deps`). libghostty-vt's `zig build`
# fetched these at build time; seed zig's cache from the pinned tarballs so it
# never reaches the network. `zig fetch <file>` reads a local tarball and
# prints its package hash, which must equal the hash upstream's build.zig.zon
# pins: a mirrored file with different contents fails here.
export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"
# Zig 0.16's `fetch` refuses to run outside a project ("no build.zig file
# found"), so run it from libghostty-vt's root with an absolute path.
BUILD_ROOT="$PWD"
seed() {
  got=$(cd vendor/libghostty-vt && "$ZIG" fetch "$BUILD_ROOT/$1")
  if [ "$got" != "$2" ]; then
    echo "herdr: $1 hashes to $got, upstream pins $2" >&2
    exit 1
  fi
}
seed arocc-f97cdfc3.tar.gz aro-0.0.0-JSD1Qk6lNgDdcDV4Vh7Sfy-34m2TluIVOdPzMmj_0BjX
seed ghostty-themes-release-20260831-151010-752a9c0.tgz N-V-__8AAEFmBABuDGOKxAI6VMg41b9euMZ-z7HS9EcUdaor
seed highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE
seed pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc
seed translate-c-4e879eb8.tar.gz translate_c-0.0.0-Q_BUWhVNBwDOEcIqub4VFPJPB6D9dgwzUMHTX5KWr8Xr
seed uucode-2826a37a4562284fdacd8fa029d49509cc9bffcd.tar.gz uucode-0.2.0-ZZjBPlK5VADj7fdoq7G8LIHzD5o6FSkcBXXrRWr4jnrA
seed wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI
seed zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz N-V-__8AAB0eQwD-0MdOEBmz7intriBReIsIDNlukNVoNu6o
seeded=$(ls "$ZIG_GLOBAL_CACHE_DIR/p" | sort)

cargo build --release

# Nothing beyond the seeded set: a herdr bump that pulls in a new zig package
# fails here, naming it, instead of quietly fetching it from the network.
fetched=$(ls "$ZIG_GLOBAL_CACHE_DIR/p" | sort)
if [ "$fetched" != "$seeded" ]; then
  echo "herdr: zig fetched packages beyond the pinned set:" >&2
  printf '%s\n' "$fetched" | grep -vxF "$seeded" >&2 || true
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
cp "target/release/herdr" "$OUTPUT_DIR/usr/bin/"
