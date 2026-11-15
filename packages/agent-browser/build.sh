#!/bin/sh
set -eu

# agent-browser >= 0.20 is a native Rust CLI (upstream #754). The npm package's
# bin/agent-browser.js is only a launcher that picks the per-platform binary
# (and scripts/postinstall.js downloads one), so we build the binary from
# source and ship it on its own: no node, no node_modules at runtime.
#
# Build order mirrors upstream's `pnpm run build:source`:
#   1. the dashboard (Next.js static export, packages/dashboard/out), which
#      cli/src/native/stream/http.rs embeds with rust-embed at compile time;
#      without it cli/build.rs embeds a "Dashboard not built" placeholder;
#   2. the Rust CLI.

# pnpm 11+: strictDepBuilds defaults to true. We install with --ignore-scripts
# (no dependency build script is needed for a static export), so keep the
# skipped builds a warning. Also skip the pre-script deps check, which would
# reinstall and re-run lifecycle scripts before `pnpm build`.
export PNPM_CONFIG_STRICT_DEP_BUILDS=false
export PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false
# Keep pnpm's store out of the source tree (pnpm 12 otherwise puts it in
# node_modules/.pnpm-store when /build is a separate mount).
export PNPM_CONFIG_STORE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm/store"
# package.json pins "packageManager": "pnpm@11.1.3". Build with our pnpm
# (engines: pnpm >= 11) instead of letting it download that one at build time
# (pmOnFail is pnpm 11+'s setting; manage-package-manager-versions pnpm 10's).
export PNPM_CONFIG_PM_ON_FAIL=ignore
export PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS=false
# No Next.js telemetry from the build.
export NEXT_TELEMETRY_DISABLED=1

# --- 1. dashboard -----------------------------------------------------------
# Only the dashboard's dependencies (the workspace also holds docs and the
# @agent-browser/{eve,sandbox} packages, none of which ship). Lockfile-pinned.
pnpm install --frozen-lockfile --ignore-scripts --filter dashboard

# Next.js bakes a random (nanoid) buildId into out/_next/static/<buildId>/ and
# every page's RSC payload; pin it so the embedded dashboard, and with it the
# binary, is reproducible (same fix as packages/next's bundle-analyzer).
sed -i 's/output: "export",/output: "export", generateBuildId: async () => "agent-browser-reproducible",/' \
  packages/dashboard/next.config.ts
grep -q 'agent-browser-reproducible' packages/dashboard/next.config.ts \
  || { echo "ERROR: dashboard generateBuildId repro patch did not apply (next.config.ts changed upstream)" >&2; exit 1; }

# next/font/google (layout.tsx's Geist) downloads the font at build time and
# self-hosts it in out/_next/static/media; the build has network via rust's
# `needs`.
(cd packages/dashboard && pnpm build)
test -f packages/dashboard/out/index.html
if grep -q 'Dashboard not built' packages/dashboard/out/index.html; then
  echo "ERROR: dashboard export is the placeholder" >&2
  exit 1
fi

# --- 2. Rust CLI ------------------------------------------------------------
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo -C codegen-units=1"
export CONST_RANDOM_SEED=0   # pin ahash/const-random compile-time seed

cargo build --release --locked --manifest-path cli/Cargo.toml

# --- install ----------------------------------------------------------------
# Layout matches the npm package, which the binary's lookups assume:
#   skills.rs     find_package_root(): <exe dir>/../skill-data/core/SKILL.md
#   stream/chat.rs find_skills_dir(): walks up from the exe to skills/agent-browser/SKILL.md
# Both canonicalize current_exe(), so the real binary must live inside the tree.
LIBEXEC=$OUTPUT_DIR/usr/libexec/agent-browser
install -d "$LIBEXEC/bin" "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/licenses/agent-browser"
install -m 0755 cli/target/release/agent-browser "$LIBEXEC/bin/agent-browser"
cp -R skills skill-data "$LIBEXEC/"
test -f "$LIBEXEC/skill-data/core/SKILL.md"
test -f "$LIBEXEC/skills/agent-browser/SKILL.md"

# Licences of what the binary embeds: axe-core (MPL-2.0, include_str! of
# axe.min.js) with its third-party notices, as upstream's package.json ships
# them; React DevTools' installHook.js (MIT, its notice is in the file).
install -m 0644 LICENSE "$OUTPUT_DIR/usr/share/licenses/agent-browser/LICENSE"
install -m 0644 cli/src/native/a11y/LICENSE-axe-core.txt \
  cli/src/native/a11y/LICENSE-axe-core-THIRD-PARTY.txt \
  "$OUTPUT_DIR/usr/share/licenses/agent-browser/"

# The wrapper sets two defaults; a caller's own env var wins, and so does a
# command-line flag.
#
# AGENT_BROWSER_EXECUTABLE_PATH -> chromium-headless-shell-bin's
#   /usr/bin/chromium-headless-shell (CVE-2026-111943 state: see build.ncl). The env
#   var (rather than the old prepended --executable-path) also reaches the
#   paths that never parse the flag: the daemon's own auto-launch
#   (native/actions.rs), `mcp` mode, and `doctor`. Upstream's fallback is to
#   look for google-chrome/chromium on PATH or a Chrome for Testing download
#   from `agent-browser install`, which we may not redistribute (inbox#284).
#
# AGENT_BROWSER_USE_SYSTEM_CA=1 -> the CLI's own HTTPS (`read`, which fetches
#   arbitrary URLs without a browser, plus `doctor`, `install`, `upgrade`,
#   `chat`, plugins) verifies against /etc/ssl/certs (ca-certificates) instead
#   of the webpki-roots bundle compiled into the binary (pkgs AGENTS.md "Do not
#   embed a trust store"; the locked webpki-roots 1.0.5 predates the
#   CVE-2026-111943 emSign distrust, RUSTSEC-2026-0381).
cat > "$OUTPUT_DIR/usr/bin/agent-browser" << 'EOF'
#!/bin/bash
export AGENT_BROWSER_EXECUTABLE_PATH="${AGENT_BROWSER_EXECUTABLE_PATH:-/usr/bin/chromium-headless-shell}"
export AGENT_BROWSER_USE_SYSTEM_CA="${AGENT_BROWSER_USE_SYSTEM_CA:-1}"
exec /usr/libexec/agent-browser/bin/agent-browser "$@"
EOF
chmod 0755 "$OUTPUT_DIR/usr/bin/agent-browser"
