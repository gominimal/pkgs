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
#
# Hermetic build path: when /pnpm-store exists (mounted by a SLSA-grade
# builder that has pre-staged the deps via `pnpm fetch` against this
# pkg's lockfile), redirect pnpm to that store and run offline.
# Otherwise fall back to the normal online install for dev iteration.
# Mirrors the if-then-else pattern next/build.sh + the cargo branch
# below already use.
if [ -d /pnpm-store ]; then
    # pnpm registers the project by symlinking into <store>/<v>/projects/,
    # which fails EROFS when the store is the read-only cs-mirror mount.
    # Copy to a writable scratch dir first (same pattern as the npm cache
    # in ts-ls / bash-language-server).
    PNPM_STORE_RW=/tmp/pnpm-store-rw
    cp -r /pnpm-store "$PNPM_STORE_RW"
    pnpm install --offline --frozen-lockfile --store-dir="$PNPM_STORE_RW" \
                 --ignore-scripts --config.node-linker=hoisted
else
    pnpm install --ignore-scripts --config.node-linker=hoisted
fi

# Build TypeScript daemon
pnpm build

# Build Rust CLI
if [ -d /cargo-vendor ]; then
    mkdir -p .cargo
    if [ -f /cargo-vendor/.cargo-config.toml ]; then
        cp /cargo-vendor/.cargo-config.toml .cargo/config.toml
    else
    cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "/cargo-vendor"
EOF
    fi
    cargo build --offline --frozen --release --manifest-path cli/Cargo.toml
else
    cargo build --release --manifest-path cli/Cargo.toml
fi

# Determine platform
case $(uname -m) in
  x86_64)  PLATFORM="linux-x64" ;;
  aarch64) PLATFORM="linux-arm64" ;;
esac

mkdir -p bin
cp cli/target/release/agent-browser bin/agent-browser-${PLATFORM}

# Chromium is provided by the chromium-bin pkg as a runtime dep. We pass
# its binary to the daemon via --executable-path; no need to ship our
# own copy or run `npx playwright install`.

install -d $OUTPUT_DIR/usr/bin
install -d $OUTPUT_DIR/usr/libexec/agent-browser

cp -R dist bin node_modules package.json $OUTPUT_DIR/usr/libexec/agent-browser/

cat > $OUTPUT_DIR/usr/bin/agent-browser << EOF
#!/bin/bash
exec /usr/libexec/agent-browser/bin/agent-browser-${PLATFORM} \\
  --executable-path /usr/bin/chromium "\$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/agent-browser
