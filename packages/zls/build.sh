#!/bin/sh
set -ex

# Keep zig's caches inside the build tree: hermetic (no $HOME dependency)
# and reproducible. The dependencies declared in build.zig.zon are fetched
# into the global cache and verified against the content hashes pinned
# there.
export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/.zig-local-cache"

# Pin the target the way upstream's own release step does (build.zig's
# release_targets are bare `{ .cpu_arch = .aarch64/.x86_64, .os_tag =
# .linux }` queries): an explicit arch selects the *baseline* CPU model,
# whereas a bare `zig build` tunes the code to the native CPU of whichever
# machine ran the build, making the output host-dependent and not
# reproducible across builders. zls does not link libc, so the result is
# a fully static executable with no runtime deps; there is no glibc
# version to pin (cf. fx, which does link libc and pins gnu.2.43).
case "$(uname -m)" in
  x86_64)  ZTARGET="x86_64-linux" ;;
  aarch64) ZTARGET="aarch64-linux" ;;
  *)       echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# ReleaseSafe is what upstream ships (.github/workflows/artifacts.yml);
# keep its debug info so a server panic reports source locations.
zig build -Doptimize=ReleaseSafe -Dtarget="$ZTARGET" --prefix "$OUTPUT_DIR/usr"
