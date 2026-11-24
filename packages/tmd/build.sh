#!/bin/bash
set -euo pipefail

# Keep zig's caches inside the build tree: hermetic (no $HOME dependency) and
# reproducible.
export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-local-cache"

# Seed zig's package directory from the pinned Sources (build.ncl); `zig
# build --system` below then resolves every package from it and nothing else.
#
# `zig fetch <file>` is the verifier: it unpacks the archive, applies the
# package's `paths` filter and prints its zig package hash, which must equal
# the hash the parent build.zig.zon pins. Its cache entry is NOT usable,
# though: without --save, zig 0.17.1 recompresses the temporary directory
# rather than the archive's root inside it (Maker/Fetch.zig: `package_root =
# tmp_directory_path`), so p/<hash>.tar.gz holds <hash>/<archive root>/...
# and `zig build` unpacks it to a tree with no build.zig.zon at the top,
# hashing it as a naked N-V-... package. So the verified archive is unpacked
# into zig-pkg/<hash>/ directly, and the broken global entries are removed
# after the last seed (under --system an entry there would trip an assert).
seed() {
  local file="$1" want="$2" got
  got="$(zig fetch "$file")"
  if [ "$got" != "$want" ]; then
    echo "zig package hash mismatch for $file: got $got, want $want" >&2
    exit 1
  fi
  # zig fetch strips the archive's single top-level directory; so does this.
  if [ "$(tar -tf "$file" | grep -v '^pax_global_header$' | cut -d/ -f1 | sort -u | wc -l)" != 1 ]; then
    echo "$file does not have a single top-level directory" >&2
    exit 1
  fi
  mkdir -p "zig-pkg/$want"
  tar -xof "$file" -C "zig-pkg/$want" --strip-components=1
  [ -n "$(ls -A "zig-pkg/$want")" ] || { echo "zig-pkg/$want is empty" >&2; exit 1; }
}
seed v1.4.0.tar.gz ghostty-1.4.0-5UdBC-qohwWqLS0BImOz05t4hVyTwbaKslyTPvKYvAtE
seed uucode-ea62149739404a73c202b48a33bf6dd2af4bd9b0.tar.gz uucode-0.2.0-ZZjBPoGFVgCiflJNFc6Io8xzC67B6PA5bUkk4LT0kCxg
seed ghostty-themes-release-20261019-151001-86a776d.tgz N-V-__8AAJ3vBQAq1fLMh5J8uWLkeDLS6WAdR2x5KcrmEyz6
seed translate_c-02ff0c523fb92a38939b04d0145c4a9602a74d56.tar.gz translate_c-2.0.0-Q_BUWltOBwBYABF84EUL208pIFeUIwbBs29FmVBaafN5
seed arocc-d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b.tar.gz aro-0.0.0-JSD1QtuBNwCASyBtNF3pqTl_W3oAJQGEVyFAtrBSE_Pa
seed zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz N-V-__8AAB0eQwD-0MdOEBmz7intriBReIsIDNlukNVoNu6o
seed wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI
seed pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc
rm -rf "$ZIG_GLOBAL_CACHE_DIR/p" "$ZIG_GLOBAL_CACHE_DIR/tmp"

# tmd links libc, so pin musl for the static binary upstream documents. An
# explicit arch also selects the baseline CPU model, where a bare `zig build`
# would tune the code to whichever machine ran the build.
case "$(uname -m)" in
  x86_64)  ZTARGET="x86_64-linux-musl" ;;
  aarch64) ZTARGET="aarch64-linux-musl" ;;
  *)       echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# ReleaseSmall is upstream's documented release build.
#
# The sandbox HAS the network: curl (a runtime dep) declares needs.internet,
# and a build gets the network when anything in its closure does. So zig
# enforces offline resolution instead: `--system <dir>` makes its package
# fetch read-only (Maker/Fetch.zig `read_only`), and a package missing from
# zig-pkg/ fails the build ("package not found" / "lazy dependency package not
# found") instead of downloading. Never drop the flag to get a build through:
# mirror the missing package (build.ncl) and seed it above.
#
# --system also sets system_package_mode, which turns ON every zig
# systemIntegrationOption that has no explicit default. ghostty declares six
# such options; each -fno-sys keeps the bundled copy, as without --system.
#
# The directory must be relative: zig roots packages at it (Path.initCwd), and
# an absolute one makes every `.path` dependency inside them (ghostty's
# ./pkg/*) fail "expected path relative to build root" (Maker/Fetch.zig).
zig build --system zig-pkg \
  -fno-sys=freetype -fno-sys=harfbuzz -fno-sys=fontconfig \
  -fno-sys=libpng -fno-sys=zlib -fno-sys=oniguruma \
  -Doptimize=ReleaseSmall -Dtarget="$ZTARGET" \
  -Dversion="$MINIMAL_ARG_VERSION" --prefix "$OUTPUT_DIR/usr"

# The binary is static, so the licences of everything compiled into it ship with it:
# tmd's own LICENSE and upstream's THIRD_PARTY_NOTICES.md (ghostty-vt, uucode, Unicode
# data, NanoSVG, stb, the Zig standard library, musl).
install -Dm644 -t "$OUTPUT_DIR/usr/share/licenses/tmd" LICENSE THIRD_PARTY_NOTICES.md
