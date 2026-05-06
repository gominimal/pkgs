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
# registry expects on disk per arch.
FULL_INNER=$(ls _full)
SHELL_INNER=$(ls _shell)

REV="${MINIMAL_ARG_REVISION}"
SHARE="$OUTPUT_DIR/usr/share/playwright-chromium"
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

# Stable wrapper for non-Playwright consumers (e.g. agent-browser).
# Points at the full chrome binary; the headless-shell variant is for
# @playwright/test's internal use.
install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/playwright-chromium" <<EOF
#!/bin/bash
exec /usr/share/playwright-chromium/chromium-${REV}/$FULL_INNER/chrome "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/playwright-chromium"
