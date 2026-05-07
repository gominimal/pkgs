#!/bin/bash
set -euo pipefail

# Two zips arrive in the cwd at known names (one for the full chromium,
# one for the headless-shell). Both arm64 zips happen to extract to a
# `chrome-linux/` top-level dir, so we extract each into its own scratch
# dir to keep them from clobbering each other.

extract_into() {
  local zip="$1" dest="$2"
  mkdir -p "$dest"
  unzip -q "$zip" -d "$dest"
}

extract_into chromium-linux*.zip _full
extract_into chromium-headless-shell-linux*.zip _shell

# Pick the top-level dir each zip created; matches what Playwright's
# registry expects on disk per arch. Each zip is expected to extract to
# exactly one top-level directory — fail loudly if that ever changes.
sole_entry() {
  local dir="$1"
  local entries=("$dir"/*)
  if [ "${#entries[@]}" -ne 1 ] || [ ! -d "${entries[0]}" ]; then
    echo "expected exactly one top-level directory in $dir, got: ${entries[*]}" >&2
    exit 1
  fi
  basename "${entries[0]}"
}

FULL_INNER=$(sole_entry _full)
SHELL_INNER=$(sole_entry _shell)

# Inner dirs differ by arch *and* variant:
#   chromium  amd64 → chrome-linux64/chrome                  (CfT direct)
#   chromium  arm64 → chrome-linux/chrome                    (Playwright arm64)
#   shell     amd64 → chrome-headless-shell-linux64/chrome-headless-shell (CfT direct)
#   shell     arm64 → chrome-linux/headless_shell            (Playwright arm64)
if [ -x "_shell/$SHELL_INNER/chrome-headless-shell" ]; then
  SHELL_BIN=chrome-headless-shell
elif [ -x "_shell/$SHELL_INNER/headless_shell" ]; then
  SHELL_BIN=headless_shell
else
  echo "unexpected headless-shell layout under _shell/$SHELL_INNER" >&2
  exit 1
fi

REV="${MINIMAL_ARG_REVISION}"
SHARE="$OUTPUT_DIR/usr/share/chromium-bin"
FULL_DEST="$SHARE/chromium-${REV}"
SHELL_DEST="$SHARE/chromium_headless_shell-${REV}"

install -d "$FULL_DEST" "$SHELL_DEST"
cp -R "_full/$FULL_INNER" "$FULL_DEST/$FULL_INNER"
cp -R "_shell/$SHELL_INNER" "$SHELL_DEST/$SHELL_INNER"

# Playwright's installer writes this marker after a successful download
# of each browser; without it @playwright/test treats the install as
# incomplete and tries to re-download.
touch "$FULL_DEST/INSTALLATION_COMPLETE"
touch "$SHELL_DEST/INSTALLATION_COMPLETE"

# Stable wrappers so consumers don't need to know per-arch dirs/binaries.
# /usr/bin/chromium                → full browser (used by agent-browser)
# /usr/bin/chromium-headless-shell → headless-shell variant (used by
#                                    Puppeteer/Playwright default headless)
#
# Note for Playwright users: setting
# PLAYWRIGHT_BROWSERS_PATH=/usr/share/chromium-bin lets @playwright/test
# discover both binaries via its registry layout without involving these
# wrappers.
install -d "$OUTPUT_DIR/usr/bin"

cat > "$OUTPUT_DIR/usr/bin/chromium" <<EOF
#!/bin/bash
exec /usr/share/chromium-bin/chromium-${REV}/$FULL_INNER/chrome "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium"

cat > "$OUTPUT_DIR/usr/bin/chromium-headless-shell" <<EOF
#!/bin/bash
exec /usr/share/chromium-bin/chromium_headless_shell-${REV}/$SHELL_INNER/$SHELL_BIN "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium-headless-shell"
