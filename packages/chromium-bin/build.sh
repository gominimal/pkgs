#!/bin/bash
set -euo pipefail

# One zip arrives in the cwd. Extract into a scratch dir so we can
# discover its (arch-dependent) top-level directory name.
mkdir -p _full
# amd64 zip from the chromium-browser-snapshots bucket is named
# chrome-linux.zip; arm64 zip from Playwright's CDN is
# chromium-linux-arm64.zip. Each build fetches exactly one zip into
# the cwd, so a broad glob is fine.
unzip -q chrom*-linux*.zip -d _full

# The zip is expected to extract to exactly one top-level directory —
# fail loudly if that ever changes.
entries=(_full/*)
if [ "${#entries[@]}" -ne 1 ] || [ ! -d "${entries[0]}" ]; then
  echo "expected exactly one top-level directory in _full, got: ${entries[*]}" >&2
  exit 1
fi
FULL_INNER=$(basename "${entries[0]}")

# Both zips extract to chrome-linux/, but Playwright's x64 registry
# expects chrome-linux64/chrome (its arm64 registry expects
# chrome-linux/chrome) — normalize on x86_64 so registry discovery via
# PLAYWRIGHT_BROWSERS_PATH keeps working on both arches.
if [ "$(uname -m)" = "x86_64" ] && [ "$FULL_INNER" = "chrome-linux" ]; then
  mv _full/chrome-linux _full/chrome-linux64
  FULL_INNER=chrome-linux64
fi

REV="${MINIMAL_ARG_REVISION}"
# Shared with chromium-headless-shell-bin so that
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` discovers
# both registry layouts when both pkgs are installed.
SHARE="$OUTPUT_DIR/usr/share/playwright-browsers"
FULL_DEST="$SHARE/chromium-${REV}"

install -d "$FULL_DEST"
cp -R "_full/$FULL_INNER" "$FULL_DEST/$FULL_INNER"

# Playwright's installer writes this marker after a successful download;
# without it @playwright/test treats the install as incomplete and tries
# to re-download.
touch "$FULL_DEST/INSTALLATION_COMPLETE"

# Stable wrapper so consumers don't need to know per-arch dirs.
install -d "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/chromium" <<EOF
#!/bin/bash
exec /usr/share/playwright-browsers/chromium-${REV}/$FULL_INNER/chrome "\$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/chromium"
