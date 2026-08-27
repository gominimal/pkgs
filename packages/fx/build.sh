#!/bin/sh
# fx (0.0.3, Zig) — vercel-labs/fx AI coding-agent harness.
set -eu

# Keep zig's caches inside the build tree: hermetic (no $HOME dependency) and
# reproducible. build.zig.zon has no dependencies, so nothing is fetched.
export ZIG_GLOBAL_CACHE_DIR="$(pwd)/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$(pwd)/.zig-cache"

# Pin the glibc target to 2.43: zig 0.16 bundles glibc stubs only through 2.43,
# so a bare `native` target against our glibc 2.44 fails ("cannot build new glibc
# version 2.44.0"). A binary built against 2.43 is forward-compatible with the
# 2.44 we ship at runtime (glibc keeps old symbol versions). fx's build.zig uses
# standardTargetOptions, so -Dtarget flows through to the linked exe.
case "$(uname -m)" in
  x86_64)  ZTARGET="x86_64-linux-gnu.2.43" ;;
  aarch64) ZTARGET="aarch64-linux-gnu.2.43" ;;
  *)       echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# app_version is read from src/main.zig; git_commit falls back to "unknown"
# without a .git dir (readGitCommit uses runAllowFail). ReleaseSafe is upstream's
# documented release build.
zig build -Doptimize=ReleaseSafe -Dtarget="$ZTARGET"

install -Dm755 zig-out/bin/fx "$OUTPUT_DIR/usr/bin/fx"
