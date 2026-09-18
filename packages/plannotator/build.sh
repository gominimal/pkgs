#!/bin/sh
set -ex

# Mirrors upstream's .github/workflows/release.yml. The compile target differs
# per arch and uses upstream's exact triple names — `-baseline` on x64 is
# deliberate there (it targets older CPUs), so we keep it rather than
# substituting plain bun-linux-x64.
case "$(uname -m)" in
  x86_64)  BUN_TARGET=bun-linux-x64-baseline ;;
  aarch64) BUN_TARGET=bun-linux-arm64 ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

bun install --frozen-lockfile

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

install -d "$OUTPUT_DIR/usr/bin"
install -m 755 plannotator "$OUTPUT_DIR/usr/bin/plannotator"
