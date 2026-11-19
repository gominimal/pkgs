#!/bin/bash
set -euo pipefail

# Keep zig's caches inside the build tree: hermetic (no $HOME dependency) and
# reproducible.
export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-local-cache"

# Seed the global cache from the pinned Sources (build.ncl), so `zig build`
# never downloads. `zig fetch <file>` unpacks a local archive, computes its zig
# package hash and stores it as p/<hash>.tar.gz; `zig build` looks there before
# it would go to the network. Each hash must equal the one the parent
# build.zig.zon pins, and the cached archive must exist: a hash that drifts
# fails here, by name, rather than as a network error in an offline sandbox.
seed() {
  local file="$1" want="$2" got
  got="$(zig fetch "$file")"
  if [ "$got" != "$want" ]; then
    echo "zig package hash mismatch for $file: got $got, want $want" >&2
    exit 1
  fi
  if [ ! -f "$ZIG_GLOBAL_CACHE_DIR/p/$want.tar.gz" ]; then
    echo "zig fetch did not cache $want for $file" >&2
    exit 1
  fi
}
seed v1.4.0.tar.gz ghostty-1.4.0-5UdBC-qohwWqLS0BImOz05t4hVyTwbaKslyTPvKYvAtE
seed uucode-ea62149739404a73c202b48a33bf6dd2af4bd9b0.tar.gz uucode-0.2.0-ZZjBPoGFVgCiflJNFc6Io8xzC67B6PA5bUkk4LT0kCxg
seed ghostty-themes-release-20261019-151001-86a776d.tgz N-V-__8AAJ3vBQAq1fLMh5J8uWLkeDLS6WAdR2x5KcrmEyz6
seed translate_c-02ff0c523fb92a38939b04d0145c4a9602a74d56.tar.gz translate_c-2.0.0-Q_BUWltOBwBYABF84EUL208pIFeUIwbBs29FmVBaafN5
seed arocc-d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b.tar.gz aro-0.0.0-JSD1QtuBNwCASyBtNF3pqTl_W3oAJQGEVyFAtrBSE_Pa
seed zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz N-V-__8AAB0eQwD-0MdOEBmz7intriBReIsIDNlukNVoNu6o
seed wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI
seed pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc

# tmd links libc, so pin musl for the static binary upstream documents. An
# explicit arch also selects the baseline CPU model, where a bare `zig build`
# would tune the code to whichever machine ran the build.
case "$(uname -m)" in
  x86_64)  ZTARGET="x86_64-linux-musl" ;;
  aarch64) ZTARGET="aarch64-linux-musl" ;;
  *)       echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# ReleaseSmall is upstream's documented release build. The sandbox has no
# network (build.ncl declares no `needs`), so this resolves every package from
# the cache seeded above or fails.
zig build -Doptimize=ReleaseSmall -Dtarget="$ZTARGET" \
  -Dversion="$MINIMAL_ARG_VERSION" --prefix "$OUTPUT_DIR/usr"

# The binary is static, so the licences of everything compiled into it ship with it:
# tmd's own LICENSE and upstream's THIRD_PARTY_NOTICES.md (ghostty-vt, uucode, Unicode
# data, NanoSVG, stb, the Zig standard library, musl).
install -Dm644 -t "$OUTPUT_DIR/usr/share/licenses/tmd" LICENSE THIRD_PARTY_NOTICES.md
