#!/bin/sh
set -e

# pnpm 11 migration: strictDepBuilds now defaults to true, so unreviewed
# dependency build scripts (esbuild/geckodriver/…) are a hard error
# (ERR_PNPM_IGNORED_BUILDS) rather than a warning — but this build deliberately
# skips them (`--ignore-scripts`; the daemon ships a prebuilt binary), so demote
# it back to a warning. Also disable the pre-script deps check, which otherwise
# reinstalls before `pnpm build` and re-runs the husky postinstall (which needs
# a `.git` the source tarball doesn't have).
export PNPM_CONFIG_STRICT_DEP_BUILDS=false
export PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false

# pnpm 12 places its default store on the project's own volume when it cannot
# hardlink into its home store, and in the sandbox /build is a separate mount,
# so the store lands in node_modules/.pnpm-store — which the `cp -R node_modules`
# below would ship. Pin it outside the build tree, where pnpm 11 put it.
export PNPM_CONFIG_STORE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm/store"

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1"
export CONST_RANDOM_SEED=0   # pin ahash/const-random compile-time seed

# Install JS deps (skip postinstall which downloads pre-built binary).
# Use the hoisted node-linker so node_modules is a flat, self-contained
# tree — pnpm's default symlinked layout into .pnpm/ doesn't survive
# being copied into $OUTPUT_DIR and causes runtime ERR_MODULE_NOT_FOUND
# on transitive deps (e.g. jszip).
pnpm install --ignore-scripts --config.node-linker=hoisted

# Build TypeScript daemon
pnpm build

# Build Rust CLI
cargo build --release --manifest-path cli/Cargo.toml

# Determine platform
case $(uname -m) in
  x86_64)  PLATFORM="linux-x64" ;;
  aarch64) PLATFORM="linux-arm64" ;;
esac

mkdir -p bin
cp cli/target/release/agent-browser bin/agent-browser-${PLATFORM}

# Chromium is provided by the chromium-headless-shell-bin pkg as a runtime
# dep. We pass its binary to the daemon via --executable-path; no need to
# ship our own copy or run `npx playwright install`.
#
# Upstream's own default is to fetch Chrome for Testing's `chrome` bundle,
# which we may not redistribute (inbox#284). Passing an explicit
# --executable-path is what stops `agent-browser install` ever reaching for
# it, so this flag is load-bearing for licensing, not just convenience.

install -d $OUTPUT_DIR/usr/bin
install -d $OUTPUT_DIR/usr/libexec/agent-browser

# pnpm bakes wall-clock timestamps into its node_modules state files
# (.modules.yaml `prunedAt`, .pnpm-workspace-state-v1.json `lastValidatedTimestamp`)
# — non-deterministic and not needed at runtime. Drop them before packaging.
rm -f node_modules/.modules.yaml node_modules/.pnpm-workspace-state-v1.json
test ! -e node_modules/.pnpm-store \
  || { echo "agent-browser: the pnpm store is inside node_modules and would ship" >&2; exit 1; }
cp -R dist bin node_modules package.json $OUTPUT_DIR/usr/libexec/agent-browser/

cat > $OUTPUT_DIR/usr/bin/agent-browser << EOF
#!/bin/bash
exec /usr/libexec/agent-browser/bin/agent-browser-${PLATFORM} \\
  --executable-path /usr/bin/chromium-headless-shell "\$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/agent-browser
