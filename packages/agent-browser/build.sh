#!/bin/sh
set -e

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

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

# Chromium is provided by the playwright-chromium pkg as a runtime dep
# (see build.ncl for why playwright-chromium and not chrome-for-testing).
# We pass its binary to the daemon via --executable-path; no need to ship
# our own copy or run `npx playwright install`.

install -d $OUTPUT_DIR/usr/bin
install -d $OUTPUT_DIR/usr/libexec/agent-browser

cp -R dist bin node_modules package.json $OUTPUT_DIR/usr/libexec/agent-browser/

cat > $OUTPUT_DIR/usr/bin/agent-browser << EOF
#!/bin/bash
exec /usr/libexec/agent-browser/bin/agent-browser-${PLATFORM} \\
  --executable-path /usr/bin/playwright-chromium "\$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/agent-browser
