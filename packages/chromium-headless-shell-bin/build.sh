#!/bin/bash
set -euo pipefail

# One complete Chrome for Testing zip arrives in the cwd — nothing to
# graft and nothing to borrow, so this is a straight extract. (Before the
# CfT move the amd64 leg pulled three archives: the snapshot
# headless-shell.zip, chrome-linux.zip for icudtl/v8/GL, and the arm64
# Playwright zip purely to donate headless_command_resources.pak.)
mkdir -p _shell
if [ "$(uname -m)" = "x86_64" ]; then
  unzip -q chrome-headless-shell-linux64.zip -d _shell
else
  unzip -q chrome-headless-shell-linux-arm64.zip -d _shell
fi

# The zip is expected to extract to exactly one top-level directory —
# fail loudly if that ever changes.
entries=(_shell/*)
if [ "${#entries[@]}" -ne 1 ] || [ ! -d "${entries[0]}" ]; then
  echo "expected exactly one top-level directory in _shell, got: ${entries[*]}" >&2
  exit 1
fi
SHELL_INNER=$(basename "${entries[0]}")
SHELL_BIN=chrome-headless-shell

if [ ! -x "_shell/$SHELL_INNER/$SHELL_BIN" ]; then
  echo "expected an executable _shell/$SHELL_INNER/$SHELL_BIN in the CfT bundle" >&2
  exit 1
fi

# Fail closed on the runtime files the old amd64 leg had to graft in. CfT
# ships them inline, but a silently-incomplete bundle would otherwise
# surface as a FATAL at first launch (headless_shell aborts on a missing
# icudtl.dat) or, worse, as --dump-dom quietly returning nothing.
for required in icudtl.dat headless_command_resources.pak; do
  if [ ! -s "_shell/$SHELL_INNER/$required" ]; then
    echo "CfT bundle is missing $required — refusing to ship an incomplete shell" >&2
    exit 1
  fi
done

REV="${MINIMAL_ARG_REVISION}"
# Shared with chromium-bin so that
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` discovers
# both registry layouts when both pkgs are installed.
SHARE="$OUTPUT_DIR/usr/share/playwright-browsers"
SHELL_DEST="$SHARE/chromium_headless_shell-${REV}"

install -d "$SHELL_DEST"
cp -R "_shell/$SHELL_INNER" "$SHELL_DEST/$SHELL_INNER"

# COMPAT: the pre-CfT arm64 leg (Playwright's own build) extracted to
# `chrome-linux/headless_shell`, and playwright-core ^1.59 — the version
# `revision` pins us to — looks there on arm64. CfT uses
# `chrome-headless-shell-linux-arm64/chrome-headless-shell` on both
# arches. Add the old names as symlinks so a PLAYWRIGHT_BROWSERS_PATH
# consumer pinned to ^1.59 keeps resolving; newer playwright-core, which
# already expects the CfT layout, uses the real directory.
# amd64 is unaffected: its dir and binary names are unchanged by the move.
if [ "$SHELL_INNER" != "chrome-linux" ]; then
  ln -s "$SHELL_INNER" "$SHELL_DEST/chrome-linux"
fi
if [ ! -e "$SHELL_DEST/$SHELL_INNER/headless_shell" ]; then
  ln -s "$SHELL_BIN" "$SHELL_DEST/$SHELL_INNER/headless_shell"
fi

# Playwright's installer writes this marker after a successful download;
# without it @playwright/test treats the install as incomplete and tries
# to re-download.
touch "$SHELL_DEST/INSTALLATION_COMPLETE"

# Stable wrapper so consumers don't need to know per-arch dirs/binaries.
install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/chromium-headless-shell" <<EOF
#!/bin/bash
exec /usr/share/playwright-browsers/chromium_headless_shell-${REV}/$SHELL_INNER/$SHELL_BIN "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium-headless-shell"
