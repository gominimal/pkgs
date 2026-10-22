#!/bin/sh
set -ex

# Upstream's .github/workflows/release.yml compiles x64 for
# bun-linux-x64-baseline (older CPUs). We use plain bun-linux-x64 instead, so
# that on both arches the target equals our own bun's default target and
# `bun build --compile` embeds OUR bun (CompileTarget.exePath -> selfExePath).
# Any other target makes bun download @oven/bun-linux-x64-baseline from the npm
# registry at build time: upstream's runtime, unpinned, without the
# CVE-2026-111943 root-store patch carried in packages/bun. Baseline buys
# nothing here: glibc and bun are built with -march=x86-64-v3, so every
# minimal amd64 machine already has AVX2.
case "$(uname -m)" in
  x86_64)  BUN_TARGET=bun-linux-x64 ;;
  aarch64) BUN_TARGET=bun-linux-arm64 ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

# --ignore-scripts: node-pty's install script shells out to node-gyp, which we
# do not ship, and the build dies with "node-gyp: command not found". Skipping
# it is safe for the artifact we produce. Upstream's own
# packages/server/agent-terminal-runtime.ts explains why:
#
#   "Bun cannot dlopen the native node-pty addon, so the PTY server ...
#    node-pty ships prebuilds for macOS and Windows only"
#
# i.e. node-pty is NOT linked into the `bun build --compile` output — it is
# located at run time, and upstream already handles it being absent. Building
# it here would produce an addon the compiled binary cannot load anyway.
bun install --frozen-lockfile --ignore-scripts

# Upstream builds the review and hook UIs before compiling; the compiled
# binary embeds their output.
bun run build:review
bun run build:hook

# __CLI_VERSION__ is injected at compile time — without it `--version` reports
# a placeholder, which is also what the smoketest would catch.
VERSION="${MINIMAL_ARG_VERSION}"
bun build apps/hook/server/index.ts \
  --compile \
  --no-compile-autoload-bunfig \
  --target="$BUN_TARGET" \
  --define "__CLI_VERSION__=\"$VERSION\"" \
  --outfile plannotator

# The runtime embedded in ./plannotator must be our bun: its compiled-in root
# store must not carry the emSign roots packages/bun removes (CVE-2026-111943).
# BUN_BE_BUN=1 makes a --compile output run as plain bun, so this checks the
# shipped binary itself, and fails if a target change ever makes bun fetch a
# stock runtime again.
cat > ./minimal-check-emsign-roots.js <<'JS'
const { X509Certificate, createHash } = require("node:crypto");
const { rootCertificates } = require("node:tls");
const removed = [
  "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b",
  "125609aa301da0a249b97a8239cb6a34216f44dcac9f3954b14292f2e8c8608f",
  "bc4d809b15189d78db3e1d8cf4f9726a795da1643ca5f1358e1ddb0edc0d7eb3",
];
const fps = new Set(rootCertificates.map(p => createHash("sha256").update(new X509Certificate(p).raw).digest("hex")));
const left = removed.filter(h => fps.has(h));
if (fps.size < 100 || left.length) { console.log(`roots=${fps.size} still bundled: ${left}`); process.exit(1); }
JS
BUN_BE_BUN=1 ./plannotator ./minimal-check-emsign-roots.js

install -d "$OUTPUT_DIR/usr/bin"
install -m 755 plannotator "$OUTPUT_DIR/usr/bin/plannotator"
