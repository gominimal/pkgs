#!/bin/bash
set -euo pipefail

# Keep zig's caches inside the build tree: hermetic (no $HOME dependency) and
# reproducible. The dependencies in build.zig.zon are fetched into the global
# cache and verified against the content hashes pinned there.
export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-local-cache"

# tmd links libc, so pin musl for the static binary upstream documents. An
# explicit arch also selects the baseline CPU model, where a bare `zig build`
# would tune the code to whichever machine ran the build.
case "$(uname -m)" in
  x86_64)  ZTARGET="x86_64-linux-musl" ;;
  aarch64) ZTARGET="aarch64-linux-musl" ;;
  *)       echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# ReleaseSmall is upstream's documented release build.
zig build -Doptimize=ReleaseSmall -Dtarget="$ZTARGET" \
  -Dversion="$MINIMAL_ARG_VERSION" --prefix "$OUTPUT_DIR/usr"

# The binary is static, so the licences of everything compiled into it ship with it:
# tmd's own LICENSE and upstream's THIRD_PARTY_NOTICES.md (ghostty-vt, uucode, Unicode
# data, NanoSVG, stb, the Zig standard library, musl).
install -Dm644 -t "$OUTPUT_DIR/usr/share/licenses/tmd" LICENSE THIRD_PARTY_NOTICES.md
