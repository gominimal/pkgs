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

# Install Chromium via Playwright
export PLAYWRIGHT_BROWSERS_PATH="$(pwd)/browsers"
npx playwright-core install chromium

# Install layout
install -d $OUTPUT_DIR/usr/bin
install -d $OUTPUT_DIR/usr/libexec/agent-browser
install -d $OUTPUT_DIR/usr/share/agent-browser

cp -R dist bin node_modules package.json $OUTPUT_DIR/usr/libexec/agent-browser/
cp -R browsers $OUTPUT_DIR/usr/share/agent-browser/browsers

# Create wrapper script
cat > $OUTPUT_DIR/usr/bin/agent-browser << EOF
#!/bin/bash
export PLAYWRIGHT_BROWSERS_PATH=/usr/share/agent-browser/browsers
exec /usr/libexec/agent-browser/bin/agent-browser-${PLATFORM} "\$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/agent-browser
